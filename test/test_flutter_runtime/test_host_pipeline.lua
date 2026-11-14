-- Frame-phase order through the actual App and Scheduler with an mp stub.
---@diagnostic disable: undefined-field, inject-field, need-check-nil, param-type-mismatch
local F = require 'framework'
local support = require 'runtime_support'
local mp_stub = require 'mp_stub'
mp_stub.install()
local app_mod = require 'host.mpv_app'
local key_mod = require 'src.widgets.key'
local basic_mod = require 'material'
local binding_mod = require 'src.widgets.widgets_binding'

F.section('runtime: host frame order and App ownership')

F.test('frame runs transient build finalize layout input paint present post in order', function()
    mp_stub.reset()
    local events = {}
    local key = key_mod.GlobalKey('frame-probe')
    local app = app_mod.App(support.Probe({ key = key, on_build = function(state)
        events[#events + 1] = 'build'
        return basic_mod.Text('value=' .. state.value)
    end }))
    mp_stub.pump()
    events = {}
    local function trace(object, method, label)
        local original = object[method]
        object[method] = function(self, ...)
            events[#events + 1] = label
            return original(self, ...)
        end
    end
    trace(app.binding.build_owner, 'finalize_tree', 'finalize')
    trace(app.owner, 'layout', 'layout')
    trace(app.input, 'update_regions', 'input')
    trace(app.owner, 'paint', 'paint')
    trace(app.presenter, 'present', 'present')
    local state = key:current_state()
    local transient
    transient = function()
        events[#events + 1] = 'transient'
        state:set_state(function() state.value = 23 end)
        app.scheduler:remove_transient(transient)
    end
    app.scheduler:add_transient(transient)
    app.scheduler:add_post_frame(function() events[#events + 1] = 'post' end)
    app:request_frame()
    mp_stub.pump()
    F.eq(table.concat(events, ','), 'transient,build,finalize,layout,input,paint,present,post',
        'actual host frame order')
    F.contains(app.presenter.overlay.data, 'value=23', 'same frame presents changed State')
    local submissions = app.presenter.overlay.updates
    app:render()
    F.eq(app.presenter.overlay.updates, submissions, 'idle frame does not submit again')
    app:shutdown()
end)

F.test('App shutdown leaves shared Binding and another owner tree alive', function()
    mp_stub.reset()
    local other = support.mount(support.Probe())
    local binding = binding_mod.WidgetsBinding.instance()
    local app = app_mod.App(basic_mod.Text('host'))
    mp_stub.pump()
    local overlay = app.presenter.overlay
    app:shutdown()
    F.eq(binding_mod.WidgetsBinding.instance(), binding, 'composition retained')
    F.ok(other.root_element:is_active(), 'other tree active')
    other.root_element.state:set_state(function() other.root_element.state.value = 25 end)
    other:flush_build()
    other.render_owner:flush_layout()
    F.eq(other.render_owner.root.size.width, 25, 'other owner still rebuilds')
    F.ok(not app.scheduler:is_frame_scheduled(), 'host scheduler stopped')
    F.eq(app.owner.root, nil, 'host render root released')
    F.ok(app.presenter._removed, 'host overlay removed')
    local updates = overlay.updates
    mp_stub.pump()
    F.eq(overlay.updates, updates, 'queued host timers do not resurrect presentation')
    F.ok(not app:shutdown(), 'App shutdown idempotent')
    other:dispose()
end)

F.test('State disposal failure cannot strand host presentation or timers', function()
    mp_stub.reset()
    local app = app_mod.App(support.Probe({ on_dispose = function() error('user dispose failed') end }))
    mp_stub.pump()
    app:request_frame()
    F.raises(function() app:shutdown() end, 'user dispose failed', 'original lifecycle error surfaced')
    F.ok(app.presenter._removed, 'presenter removed after failure')
    F.eq(app.clock.handler, nil, 'clock detached after failure')
    F.eq(app.owner.root, nil, 'owner cleared after failure')
    F.ok(not app.scheduler:is_frame_scheduled(), 'scheduler stopped after failure')
    F.ok(binding_mod.WidgetsBinding.instance():is_initialized(), 'shared binding remains usable')
end)

F.test('failed mount releases partial host resources and supplied disposer once', function()
    mp_stub.reset()
    local disposed = 0
    F.raises(function()
        app_mod.App(support.Probe({
            on_build = function()
                error('initial mount failed')
            end,
        }), {
            on_dispose = function()
                disposed = disposed + 1
            end,
        })
    end, 'initial mount failed', 'original mount error')
    F.eq(disposed, 1, 'external cleanup ran once')
    F.eq(mp_stub.fake.overlay.removes, 1, 'partial presenter removed')
    F.ok(binding_mod.WidgetsBinding.instance():is_initialized(), 'shared Binding survived')
    local app = app_mod.App(basic_mod.Text('after failure'))
    mp_stub.pump()
    F.contains(app.presenter.overlay.data, 'after failure', 'runtime can restart')
    app:shutdown()
end)

F.test('observer and input initialization errors clean earlier resources', function()
    -- Each cached host module retains the mp stub installed when it was loaded.
    local function captured_mp(callback)
        for index = 1, 20 do
            local name, value = debug.getupvalue(callback, index)
            if name == 'mp' then
                return value
            end
        end
        error('host callback has no mp upvalue')
    end
    for _, failing_name in ipairs({ 'display-fps', 'mouse-pos' }) do
        mp_stub.reset()
        local observer_method = failing_name == 'mouse-pos' and require('host.mpv_input').MpInput._bind_mouse
            or app_mod.App._observe
        local mp = captured_mp(observer_method)
        local original = mp.observe_property
        local disposed = 0
        local old_unobserve = mp.unobserve_property
        mp.observe_property = function(name, kind, callback)
            original(name, kind, callback)
            if name == failing_name then
                error('observer installation failed ' .. name)
            end
        end
        local ok, err = pcall(app_mod.App, basic_mod.Text('partial'), {
            on_dispose = function()
                disposed = disposed + 1
            end,
        })
        mp.observe_property = original
        mp.unobserve_property = old_unobserve
        F.ok(not ok and tostring(err):find('observer installation failed', 1, true),
            'original observer error ' .. failing_name)
        F.eq(disposed, 1, 'one external disposer ' .. failing_name)
        F.eq(mp_stub.fake.overlay.removes, 1, 'presenter removed ' .. failing_name)
        for _, event in ipairs(mp_stub.fake.events) do
            local released = false
            for _, unobserved in ipairs(mp_stub.fake.unobserved) do
                released = released or event.cb == unobserved
            end
            F.ok(released, 'partial observer released: ' .. event.name)
        end
    end
end)

F.test('player adapter disposes context after mount or user teardown failure', function()
    local player_app = require 'host.mpv_player_app'
    local context_mod = require 'host.mpv_player_context'
    local PlayerStore = require('player.src.context').PlayerStore
    for _, during_mount in ipairs({ true, false }) do
        mp_stub.reset()
        local store = PlayerStore()
        local context = context_mod.MpPlayerContext(store)
        local calls = 0
        local dispose = context.dispose
        context.dispose = function(self)
            calls = calls + 1
            return dispose(self)
        end
        F.raises(function()
            local app = player_app.PlayerHostApp(support.Probe({
                on_build = during_mount and function() error('player mount failed') end or nil,
                on_dispose = not during_mount and function() error('player dispose failed') end or nil,
            }), { player_store = store, player_context = context })
            app:shutdown()
        end, during_mount and 'player mount failed' or 'player dispose failed', 'player failure surfaced')
        F.eq(calls, 1, 'context has one cleanup owner')
        F.ok(context._disposed, 'context closed')
        F.eq(next(store._subscriptions), nil, 'partial PlayerScope subscription released')
        for _, event in ipairs(mp_stub.fake.events) do
            local released = false
            for _, unobserved in ipairs(mp_stub.fake.unobserved) do
                released = released or event.cb == unobserved
            end
            F.ok(released, 'player observer released: ' .. event.name)
        end
        F.eq(mp_stub.fake.overlay.removes, 1, 'player presenter removed')
    end
end)
