-- Frame-phase order through the actual App and Scheduler with an mp stub.
---@diagnostic disable: undefined-field, inject-field, need-check-nil, param-type-mismatch
local F = require 'framework'
local support = require 'runtime_support'
local mp_stub = require 'mp_stub'
mp_stub.install()
local app_mod = require 'host.mpv_app'
local key_mod = require 'widget.key'
local basic_mod = require 'widget.widgets.basic'
local binding_mod = require 'widget.widgets_binding'

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
