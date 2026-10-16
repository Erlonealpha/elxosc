-- Host-level OverlayHost/Registry behavior.

---@diagnostic disable: undefined-field, inject-field, need-check-nil, generic-constraint-mismatch, preferred-local-alias, unused

local F = require('framework')
local std = require('elxlibs.std')

local mp_stub = require('mp_stub')
mp_stub.install()

local fake = mp_stub.fake
local overlay_host = require('host.overlay_host')
local layout_widgets = require('widget.widgets.layout')
local basic_widgets = require('widget.widgets.basic')
local state_mod = require('widget.state')
local widget_mod = require('widget.widget')
local bind_mod = require('widget.bind')
local player_context = require('widget.player_context')

local Column = layout_widgets.Column
local Text = basic_widgets.Text
local Button = basic_widgets.Button
local State = state_mod.State
local StatefulWidget = widget_mod.StatefulWidget
local Slot = bind_mod.Slot
local BindRegistry = bind_mod.BindRegistry
local PlayerStore = player_context.PlayerStore
local OverlayHost = overlay_host.OverlayHost

local function text_root(value)
    return Text(value)
end

local function button_root(label, on_click)
    return Button({ label = label, on_click = on_click })
end

F.section('overlay host: registry and shared frame pipeline')

F.test('layers share one clock and scheduler', function()
    mp_stub.reset()
    local host = OverlayHost()
    local first = host:create('first', text_root('one'), { z_policy = 'main' })
    local second = host:create('second', text_root('two'), { z_policy = 'extension' })

    F.ok(first.registration_sequence < second.registration_sequence, 'registration sequence is stable')
    F.ok(first.binding ~= nil and second.binding ~= nil, 'both layers are mounted')
    F.ok(first.binding.build_owner.scheduler == host.scheduler, 'first binding shares scheduler')
    F.ok(second.binding.build_owner.scheduler == host.scheduler, 'second binding shares scheduler')
    F.eq(#fake.timeouts, 1, 'two dirty layers coalesce into one frame timer')
    mp_stub.pump()
    F.ok(fake.overlays[1].data ~= nil and fake.overlays[2].data ~= nil,
        'one shared frame presents both layers')
    host:shutdown()
end)

F.test('named z policy is host-owned and arbitrary z is rejected', function()
    mp_stub.reset()
    local host = OverlayHost()
    local layer = host:create('named', text_root('named'), { z_policy = 'system' })
    F.eq(layer.z, overlay_host.Z_POLICIES.system, 'system policy receives host z')
    F.raises(function()
        host:create('raw', text_root('raw'), { z = 999999 })
    end, 'arbitrary z', 'raw z is not an extension API')
    host:shutdown()
end)

F.test('same z routes input to the later registered visible interactive layer', function()
    mp_stub.reset()
    local lower_clicks, upper_clicks = 0, 0
    local host = OverlayHost()
    host:create('lower', button_root('lower', function() lower_clicks = lower_clicks + 1 end), {
        z_policy = 'extension',
        input_policy = 'interactive',
    })
    host:create('upper', button_root('upper', function() upper_clicks = upper_clicks + 1 end), {
        z_policy = 'extension',
        input_policy = 'interactive',
    })
    host:render()

    fake.mouse = { x = 5, y = 5, hover = true }
    for _, event in ipairs(fake.events) do
        if event.name == 'mouse-pos' then
            event.cb(nil, fake.mouse)
        end
    end
    fake.bindings.list[1][3]()
    fake.bindings.list[1][2]()
    F.eq(upper_clicks, 1, 'later same-z layer receives the click')
    F.eq(lower_clicks, 0, 'lower same-z layer is not selected')
    host:shutdown()
end)

F.test('passive layers do not block an interactive layer below them', function()
    mp_stub.reset()
    local lower_clicks, passive_clicks = 0, 0
    local host = OverlayHost()
    host:create('lower', button_root('lower', function() lower_clicks = lower_clicks + 1 end), {
        z_policy = 'main',
        input_policy = 'interactive',
    })
    host:create('passive', button_root('passive', function() passive_clicks = passive_clicks + 1 end), {
        z_policy = 'system',
        input_policy = 'passive',
    })
    host:render()
    fake.mouse = { x = 5, y = 5, hover = true }
    for _, event in ipairs(fake.events) do
        if event.name == 'mouse-pos' then
            event.cb(nil, fake.mouse)
        end
    end
    fake.bindings.list[1][3]()
    fake.bindings.list[1][2]()
    F.eq(lower_clicks, 1, 'interactive lower layer receives input')
    F.eq(passive_clicks, 0, 'passive layer receives no input')
    host:shutdown()
end)

F.test('an exclusive layer blocks lower input even without an interactive child', function()
    mp_stub.reset()
    local lower_clicks = 0
    local host = OverlayHost()
    host:create('lower', button_root('lower', function() lower_clicks = lower_clicks + 1 end), {
        z_policy = 'main',
        input_policy = 'interactive',
    })
    host:create('modal', Text('modal'), {
        z_policy = 'popup',
        input_policy = 'exclusive',
    })
    host:render()
    fake.mouse = { x = 5, y = 5, hover = true }
    for _, event in ipairs(fake.events) do
        if event.name == 'mouse-pos' then
            event.cb(nil, fake.mouse)
        end
    end
    fake.bindings.list[1][3]()
    fake.bindings.list[1][2]()
    F.eq(lower_clicks, 0, 'exclusive policy prevents lower input fallthrough')
    host:shutdown()
end)

F.test('hide clears output and input while retaining state by default', function()
    mp_stub.reset()
    local disposed = 0
    local TestState = std.class.new('test.overlayHost.KeepState', { State })
    function TestState:dispose()
        disposed = disposed + 1
    end
    local TestWidget = std.class.new('test.overlayHost.KeepWidget', { StatefulWidget })
    function TestWidget:create_state()
        return TestState()
    end
    function TestState:build()
        return Text('stateful')
    end

    local host = OverlayHost()
    local layer = host:create('keep', TestWidget(), {
        z_policy = 'popup',
        input_policy = 'interactive',
    })
    host:render()
    local state = layer.binding.root_element.state
    local output = layer.presenter.overlay
    F.ok(output.data ~= nil and #output.data > 0, 'layer initially has ASS output')
    host:hide('keep')
    F.eq(layer.visible, false, 'hide changes visibility')
    F.eq(layer.mounted, true, 'hide keeps the tree mounted by default')
    F.eq(disposed, 0, 'hide retains State')
    F.eq(output.data, '', 'hide clears ASS output')
    F.ok(#host.input_router:pointer_regions() == 0, 'hide removes input regions')
    host:show('keep')
    F.ok(layer.binding.root_element.state == state, 'show restores the same State')
    host:remove('keep')
    F.eq(disposed, 1, 'remove disposes retained State')
    F.eq(host.registry:get('keep'), nil, 'remove deletes the registry record')
    F.ok(output.removed, 'remove releases the presenter')
    host:shutdown()
end)

F.test('capture is bound to a layer and cancelled by hide and root swap', function()
    mp_stub.reset()
    local upper_clicks, lower_clicks = 0, 0
    local host = OverlayHost()
    host:create('lower', button_root('lower', function() lower_clicks = lower_clicks + 1 end), {
        z_policy = 'main',
        input_policy = 'interactive',
    })
    local upper = host:create('upper', button_root('upper', function() upper_clicks = upper_clicks + 1 end), {
        z_policy = 'system',
        input_policy = 'interactive',
    })
    host:render()
    fake.mouse = { x = 5, y = 5, hover = true }
    for _, event in ipairs(fake.events) do
        if event.name == 'mouse-pos' then
            event.cb(nil, fake.mouse)
        end
    end
    fake.bindings.list[1][3]()
    F.eq(host.input_router.capture_layer_id, 'upper', 'capture records the selected layer')
    host:hide('upper')
    F.eq(host.input_router.capture_layer_id, nil, 'hide cancels layer capture')
    fake.bindings.list[1][2]()
    F.eq(upper_clicks, 0, 'hidden layer receives no stale release')
    F.eq(lower_clicks, 0, 'cancelled sequence does not fall through')

    host:show('upper')
    host:render()
    fake.mouse = { x = 5, y = 5, hover = true }
    fake.bindings.list[1][3]()
    host:update('upper', Text('replacement'))
    F.eq(host.input_router.capture_layer_id, nil, 'root swap cancels capture')
    fake.bindings.list[1][2]()
    F.eq(upper_clicks, 0, 'old root does not receive stale release')
    host:remove('lower')
    host:remove('upper')
    host:shutdown()
end)

F.test('update replaces the layer store and bind registry before remounting', function()
    mp_stub.reset()
    local first_store = PlayerStore({ value = 1 })
    local second_store = PlayerStore({ value = 2 })
    local first_binds = BindRegistry()
    local second_binds = BindRegistry()
    first_binds:add('slot', Text('first'))
    second_binds:add('slot', Text('second'))
    local host = OverlayHost()
    local layer = host:create('update', Column({ children = { Slot('slot') } }), {
        binds = first_binds,
        player_store = first_store,
        input_policy = 'passive',
    })
    host:render()
    host:update('update', Column({ children = { Slot('slot') } }), {
        binds = second_binds,
        player_store = second_store,
        input_policy = 'passive',
    })
    host:render()
    F.eq(layer.binds, second_binds, 'bind registry replaced')
    F.eq(layer.player_store, second_store, 'player store replaced')
    F.eq(layer.owner.root:children()[1].paragraph.text, 'second',
        'new bind applied to the replacement root')
    host:shutdown()
end)

F.test('keep_alive false unmounts on hide and remounts fresh on show', function()
    mp_stub.reset()
    local disposed = 0
    local TestState = std.class.new('test.overlayHost.NonKeepState', { State })
    function TestState:dispose()
        disposed = disposed + 1
    end
    local TestWidget = std.class.new('test.overlayHost.NonKeepWidget', { StatefulWidget })
    function TestWidget:create_state()
        return TestState()
    end
    function TestState:build()
        return Text('non-keep')
    end

    local host = OverlayHost()
    local layer = host:create('non-keep', TestWidget(), {
        keep_alive = false,
        visible = true,
    })
    host:render()
    local old_state = layer.binding.root_element.state
    host:hide('non-keep')
    F.eq(layer.mounted, false, 'non-keep hide unmounts the tree')
    F.eq(disposed, 1, 'non-keep hide disposes State')
    host:show('non-keep')
    host:render()
    F.ok(layer.mounted, 'show remounts the layer')
    F.ok(layer.binding.root_element.state ~= old_state, 'show creates fresh State')
    host:shutdown()
end)

F.test('shutdown cancels layers, removes presenters, and disposes shared scheduler', function()
    mp_stub.reset()
    local host = OverlayHost()
    host:create('one', Column({ children = { Text('one') } }))
    host:create('two', Column({ children = { Text('two') } }))
    mp_stub.pump()
    local first, second = fake.overlays[1], fake.overlays[2]
    F.ok(host.scheduler:is_frame_scheduled() == false, 'render consumed the scheduled frame')
    F.ok(host:shutdown(), 'shutdown succeeds once')
    F.ok(first.removed and second.removed, 'all presenters are removed')
    F.ok(not host.clock:has_handler(), 'shared clock handler is released')
    F.ok(not host:shutdown(), 'shutdown is idempotent')
end)
