-- Instrumentation loaded only in the benchmark's staged entry, before App.start.
local mp = require 'mp'
local utils = require 'mp.utils'
local ffi = require 'ffi'
local app_mod = require 'host.mpv_player_app'
local input_mod = require 'host.mpv_input'

local now = mp.get_time
if ffi.os == 'Windows' then
    ffi.cdef [[
        int QueryPerformanceCounter(int64_t *value);
        int QueryPerformanceFrequency(int64_t *value);
    ]]
    local frequency = ffi.new('int64_t[1]') --[[@as integer[] ]]
    local counter = ffi.new('int64_t[1]') --[[@as integer[] ]]
    ffi.C.QueryPerformanceFrequency(frequency)
    local divisor = assert(tonumber(frequency[0]))
    now = function()
        ffi.C.QueryPerformanceCounter(counter)
        return assert(tonumber(counter[0])) / divisor
    end
end

local active = false
local events, frames = {}, {}
local latest
local stages = {}
local painting_tooltip = false
local label
local frame_started
local layout_needed = false
---@type any
local current_app
local frame_native = {}
local native_command = mp.command_native
mp.command_native = function(command)
    local started = now()
    local result, err = native_command(command)
    if active and command._name == 'osd-overlay' and command.hidden and command.compute_bounds then
        frame_native[#frame_native + 1] = now() - started
    end
    return result, err
end

-- Dynamic method instrumentation preserves arguments and all return values.
---@param target any
---@param name string
---@param stage string
local function measure(target, name, stage)
    local original = target[name]
    target[name] = function(self, ...)
        local started = now()
        if active and stage == 'layout' then
            layout_needed = self:needs_layout()
        end
        local function pack(...)
            return { n = select('#', ...), ... }
        end
        local result = pack(original(self, ...))
        if active then
            local elapsed = now() - started
            -- preparation is called within layout(); keep stage timings exclusive.
            if stage == 'layout' then
                elapsed = math.max(0, elapsed - (stages.prepare or 0))
            end
            stages[stage] = (stages[stage] or 0) + elapsed
        end
        return unpack(result, 1, result.n)
    end
end

local opts = mp.get_property_native('options/script-opts') or {}
if opts['elxosc-bench-input'] == 'mouse_move' then
    local input_class = input_mod.MpInput --[[@as table<string, any>]]
    local bind = input_class._bind_mouse
    input_class._bind_mouse = function(self)
        bind(self)
        local callback = assert(self._mouse_callback) --[[@as fun(name: string, mouse: table)]]
        mp.unobserve_property(callback --[[@as fun(name: string)]])
        -- Retain hover-leave/capture cleanup; moves use the native input event.
        self._mouse_callback = function(name, mouse)
            if mouse and not mouse.hover then
                callback(name, mouse)
            end
        end
        mp.observe_property('mouse-pos', 'native', self._mouse_callback)
        mp.add_forced_key_binding('mouse_move', 'elxosc-bench-move', function()
            callback('mouse-pos', mp.get_property_native('mouse-pos'))
        end)
    end
    mp.register_event('shutdown', function()
        mp.remove_key_binding('elxosc-bench-move')
    end)
end

local app_api = app_mod --[[@as table<string, any>]]
local start = app_api.start
app_api.start = function(build, options)
    local app = start(build, options) --[[@as any]]
    current_app = app
    measure(app, 'notify_activity', 'activity')
    measure(app.binding, 'flush_build', 'build')
    measure(app.owner, 'layout', 'layout')
    if app.owner.flush_prepare then
        measure(app.owner, 'flush_prepare', 'prepare')
    end
    measure(app.input, 'update_regions', 'regions')
    measure(app.owner, 'paint', 'paint_ass')
    measure(app.presenter, 'present', 'present')

    local dispatch = app.input._dispatch
    app.input._dispatch = function(self, event, ...)
        local stamp = now()
        local result = dispatch(self, event, ...)
        if active and event == 'move' then
            latest = { seq = #events + 1, time = stamp, finish = now(), x = self.x, y = self.y }
            events[#events + 1] = latest
        end
        return result
    end

    local draw_text = app.canvas.draw_text
    app.canvas.draw_text = function(self, paragraph, position, paint)
        if active and paint and paint.anchor == 'bottom_center'
            and paragraph.text:match('^%d+:%d+') then
            painting_tooltip = true
            label = paragraph.text
        end
        return draw_text(self, paragraph, position, paint)
    end

    local render = app.render
    app.render = function(self)
        if not active then
            return render(self)
        end
        frame_started = now()
        local generation = self.owner:region_snapshot().generation
        local build_dirty = self.binding.build_owner:has_dirty()
        stages = {}
        painting_tooltip = false
        local input = latest
        frame_native = {}
        local text_before = self.text_layout:cache_stats()
        local result = render(self)
        local text_after = self.text_layout:cache_stats()
        if painting_tooltip and input then
            frames[#frames + 1] = {
                input_seq = input.seq, start = frame_started, finish = now(), label = label,
                stages = stages,
                layout_needed = layout_needed, build_dirty = build_dirty,
                regions_changed = generation ~= self.owner:region_snapshot().generation,
                native_calls = text_after.native_calls - text_before.native_calls,
                cache_hits = text_after.hits - text_before.hits,
                native_seconds = frame_native,
                ass_events = #self.canvas.events, ass_bytes = #self.canvas:text(),
                text_generation = self.text_layout_generation,
            }
        end
        return result
    end
    return app
end

mp.register_script_message('elxosc-bench-begin', function()
    events, frames = {}, {}
    latest = nil
    active = true
end)

mp.register_script_message('elxosc-bench-refresh', function()
    current_app:refresh_text_layout()
    current_app:render()
end)

mp.register_script_message('elxosc-bench-offline', function()
    current_app:refresh_text_layout()
    current_app.text_layout._measure_ass = nil
    current_app:render()
end)

mp.register_script_message('elxosc-bench-save', function()
    active = false
    local report = {
        events = events, frames = frames, runtime = jit.version, platform = ffi.os,
        qpc = ffi.os == 'Windows', clock_delay = current_app.clock.delay,
        width = current_app.display.width, height = current_app.display.height,
        estimated_fps = mp.get_property_number('estimated-display-fps'),
        display_fps = mp.get_property_number('display-fps'),
        host_version = mp.get_property('mpv-version'),
        thumbfast = current_app.player_store:get():capability('thumbfast').status,
        text_cache = current_app.text_layout:cache_stats(),
        text_generation = current_app.text_layout_generation,
        elxlib = require 'elxlib.version',
    }
    local file = assert(io.open(mp.get_script_directory() .. '/hover-trace.json', 'w'))
    local encoded = assert(utils.format_json(report)) --[[@as string]]
    file:write(encoded)
    file:close()
    mp.set_property('user-data/elxosc-bench-saved', 'yes')
end)
