-- Loaded only in isolated investigation staging; never by the production entry.
local mp = require 'mp'
---@type any
local current_app
local updates = 0
local refs = setmetatable({}, { __mode = 'v' })
local probe_options = mp.get_property_native('options/script-opts') or {}
local standalone_overlay
local standalone_timer

local function standalone_ass()
    if probe_options['elxosc-memory-ass'] == 'static' or probe_options['elxosc-memory-ass'] == 'dynamic' then
        standalone_overlay = mp.create_osd_overlay('ass-events')
        standalone_overlay.res_x, standalone_overlay.res_y = 1280, 720
        local tick = 0
        standalone_timer = mp.add_periodic_timer(1 / 60, function()
            tick = tick + 1
            local label = probe_options['elxosc-memory-ass'] == 'dynamic' and tostring(tick) or 'Static'
            standalone_overlay.data = '{\\an7\\pos(50,50)\\fs24\\fnArial\\bord0}' .. label
            standalone_overlay:update()
        end)
    end
end

local function stop_presentation()
    if current_app then
        current_app.presenter.present = function()
            return false
        end
        current_app.presenter:remove()
    end
    if standalone_timer then
        standalone_timer:kill()
    end
    if standalone_overlay then
        standalone_overlay:remove()
    end
end
mp.register_script_message('elxosc-memory-stop-present', stop_presentation)
mp.register_event('shutdown', stop_presentation)
mp.register_script_message('elxosc-memory-stop-app', function()
    if current_app then
        current_app:shutdown()
    end
end)

local function hide_main()
    local function visit(element)
        local state = element.state
        if state and state.__name == 'DefaultAppState' then
            state.main_controller:hide()
        end
        for _, child in ipairs(element:element_children()) do
            visit(child)
        end
    end
    if current_app and current_app.binding.root_element then
        visit(current_app.binding.root_element)
    end
end
mp.register_script_message('elxosc-memory-hide', hide_main)

local function count_refs()
    local count = 0
    for _ in pairs(refs) do
        count = count + 1
    end
    return count
end

local function visibility()
    local result = {}
    local function visit(element)
        local state = element.state
        if state and state.__name == 'AutoHideState' then
            result[#result + 1] = { hidden = state.hidden, opacity = state.opacity }
        end
        for _, child in ipairs(element:element_children()) do
            visit(child)
        end
    end
    if current_app and current_app.binding.root_element then
        visit(current_app.binding.root_element)
    end
    return result
end

local function sample(force_gc)
    local before = collectgarbage('count')
    if force_gc == 'gc' then
        collectgarbage('collect')
        collectgarbage('collect')
    end
    mp.set_property_native('user-data/elxosc-memory', {
        time = mp.get_time(), lua_kib = collectgarbage('count'), before_gc_kib = before,
        forced_gc = force_gc == 'gc', updates = updates, weak_survivors = count_refs(),
        visibility = visibility(), runtime = jit.version,
    })
end

mp.register_script_message('elxosc-memory-sample', sample)

-- The no-UI control loads this file directly and has no framework dependency.
if mp.get_script_directory() then
    local app_mod = require 'host.mpv_app'
    local player_mod = require 'widget.player_context'
    local app_api = app_mod --[[@as any]]
    local start = app_api.start
    app_api.start = function(build, options)
        current_app = start(build, options)
        if probe_options['elxosc-memory-no-present'] == 'yes' then
            current_app.presenter.present = function()
                return false
            end
        end
        if probe_options['elxosc-memory-hidden'] == 'yes' then
            current_app.notify_activity = function()
                -- Suppress OS activity only in the isolated hidden control.
            end
        end
        return current_app
    end
    local store_class = player_mod.PlayerStore --[[@as any]]
    local replace = store_class.replace
    store_class.replace = function(self, snapshot)
        updates = updates + 1
        refs[(updates - 1) % 128 + 1] = self:get()
        return replace(self, snapshot)
    end
else
    standalone_ass()
end
