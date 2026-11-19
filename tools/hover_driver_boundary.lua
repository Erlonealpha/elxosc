-- Scoped deterministic mp boundary for the shared hover driver. No production imports.
---@namespace elxosc.tools.hover

local M = {}
local wall = require 'tools.benchmark_support'
local active = false

---@class HoverBoundary
---@field time number
---@field width integer
---@field height integer
---@field font string
---@field timers HoverTimer[]
---@field observers table<function, string>
---@field events table<function, string>
---@field sections table<string, boolean>
---@field overlays table<integer, boolean>
---@field counts table<string, integer>
---@field original table<string, function>
---@field native_requests table[]
---@field native_seconds number[]
---@field replay_index integer
---@field replay_error string?
---@field restore fun()
---@field emit fun(self: HoverBoundary): boolean
---@field resources fun(self: HoverBoundary): table<string, integer>

---@class HoverTimer
---@field due number
---@field enabled boolean
---@field callback fun()?
---@field kill fun(self: HoverTimer)

local function count_keys(values)
    local count = 0
    for _ in pairs(values) do
        count = count + 1
    end
    return count
end

--- Restore every replaced slot, including failures during application construction.
--- The scope is deliberately non-reentrant; user callbacks must not start another driver.
---@param mp table
---@param real_host boolean
---@return HoverBoundary
function M.install(mp, real_host, options)
    assert(not active, 'hover boundary is already active')
    active = true
    options = options or {}
    local original, slots = {}, {}
    local boundary = {
        time = 0, width = 1280, height = 720, font = 'Arial',
        timers = {}, observers = {}, events = {}, sections = {}, overlays = {},
        counts = { requested = 0, emitted = 0, updates = 0, removed = 0, estimate_requests = 0 },
        original = original,
        native_requests = {}, replay_index = 0,
        native_seconds = {},
        restore = function() end,
        emit = function() return false end,
        resources = function() return {} end,
    } --[[@as HoverBoundary]]
    local function replace(name, callback)
        slots[#slots + 1] = name
        original[name] = mp[name]
        mp[name] = callback
    end
    boundary.restore = function()
        for _, name in ipairs(slots) do
            mp[name] = original[name]
        end
        active = false
    end
    replace('get_time', function()
        if options.paced and not options.executing then
            return original.get_time()
        end
        return boundary.time
    end)
    replace('get_osd_size', function()
        return boundary.width, boundary.height
    end)
    replace('get_property_native', function(name, fallback)
        if name == 'osd-font' then
            return boundary.font
        end
        if name == 'mouse-pos' then
            return { x = 0, y = 0, hover = false }
        end
        return fallback
    end)
    replace('get_property_number', function(name, fallback)
        if name == 'display-fps' or name == 'estimated-display-fps' then
            return 240
        end
        return fallback
    end)
    replace('observe_property', function(name, _kind, callback)
        boundary.observers[callback] = name
    end)
    replace('unobserve_property', function(callback)
        boundary.observers[callback] = nil
    end)
    replace('register_event', function(name, callback)
        boundary.events[callback] = name
    end)
    replace('unregister_event', function(callback)
        boundary.events[callback] = nil
    end)
    replace('add_timeout', function(delay, callback)
        local timer = { due = boundary.time + delay, callback = callback, enabled = true }
        function timer:kill()
            self.enabled = false
            self.callback = nil
        end
        boundary.timers[#boundary.timers + 1] = timer
        boundary.counts.requested = boundary.counts.requested + 1
        return timer
    end)
    replace('set_key_bindings', function(bindings, section, ...)
        boundary.sections[section] = false
        if real_host then
            local inert = {}
            local function ignore()
            end
            for index, binding in ipairs(bindings) do
                inert[index] = { binding[1], ignore, ignore }
            end
            return original.set_key_bindings(inert, section, ...)
        end
    end)
    replace('enable_key_bindings', function(section, ...)
        boundary.sections[section] = true
        if real_host then
            return original.enable_key_bindings(section, ...)
        end
    end)
    replace('disable_key_bindings', function(section)
        boundary.sections[section] = false
        if real_host then
            return original.disable_key_bindings(section)
        end
    end)
    replace('set_mouse_area', function(...)
        if real_host then
            return original.set_mouse_area(...)
        end
    end)
    replace('command_native', function(command)
        if command._name == 'osd-overlay' and command.compute_bounds then
            boundary.counts.estimate_requests = boundary.counts.estimate_requests + 1
            local request = { data = command.data, res_x = command.res_x, res_y = command.res_y }
            if options.text_mode == 'record' then
                assert(real_host, 'native record requires real host')
                local started = wall.now()
                local raw, err = original.command_native(command)
                boundary.native_seconds[#boundary.native_seconds + 1] = wall.now() - started
                boundary.native_requests[#boundary.native_requests + 1] = { request = request,
                    raw = raw, error = err }
                return raw, err
            elseif options.text_mode == 'replay' then
                boundary.replay_index = boundary.replay_index + 1
                local record = options.corpus[boundary.replay_index]
                if not (record and record.request.data == request.data
                    and record.request.res_x == request.res_x and record.request.res_y == request.res_y) then
                    boundary.replay_error = 'native replay request mismatch at ' .. boundary.replay_index
                    error(boundary.replay_error)
                end
                return record.raw, record.error
            end
            return nil, 'hover estimate-pair boundary'
        end
        if command._name == 'osd-overlay' and command.format == 'none' then
            local raw, err
            if real_host then
                raw, err = original.command_native(command)
                if err then
                    return raw, err
                end
            end
            if boundary.overlays[command.id] then
                boundary.overlays[command.id] = nil
                boundary.counts.removed = boundary.counts.removed + 1
            end
            return raw or {}
        end
        if real_host then
            return original.command_native(command)
        end
        return {}
    end)
    local next_id = 0
    replace('create_osd_overlay', function(format)
        local native
        if real_host then
            native = original.create_osd_overlay(format)
        end
        next_id = next_id + 1
        local overlay = { id = native and native.id or next_id, format = format }
        boundary.overlays[overlay.id] = true
        function overlay:update()
            boundary.counts.updates = boundary.counts.updates + 1
            if native then
                for key, value in pairs(self) do
                    if type(value) ~= 'function' then
                        native[key] = value
                    end
                end
                return native:update()
            end
        end
        function overlay:remove()
            if native then
                native:remove()
            end
            if boundary.overlays[self.id] then
                boundary.overlays[self.id] = nil
                boundary.counts.removed = boundary.counts.removed + 1
            end
        end
        return overlay
    end)
    function boundary:emit()
        local ready, pending = nil, {}
        for _, timer in ipairs(self.timers) do
            if timer.enabled then
                if timer.due <= self.time + 1e-9 and ready == nil then
                    ready = timer
                else
                    pending[#pending + 1] = timer
                end
            end
        end
        self.timers = pending
        if ready then
            local callback = assert(ready.callback) --[[@as fun()]]
            ready:kill()
            self.counts.emitted = self.counts.emitted + 1
            callback()
            return true
        end
        return false
    end
    function boundary:resources()
        local timers, sections = 0, 0
        for _, timer in ipairs(self.timers) do
            if timer.enabled then
                timers = timers + 1
            end
        end
        for _, enabled in pairs(self.sections) do
            if enabled then
                sections = sections + 1
            end
        end
        return {
            timers = timers, observers = count_keys(self.observers), events = count_keys(self.events),
            overlays = count_keys(self.overlays), sections = sections,
        }
    end
    return boundary
end

return M
