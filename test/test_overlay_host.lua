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
local geometry = require('foundation.geometry')
local demo_mod = require('demo')
local player = require('player')

local Column = layout_widgets.Column
local Text = basic_widgets.Text
local Button = basic_widgets.Button
local State = state_mod.State
local StatefulWidget = widget_mod.StatefulWidget
local Slot = bind_mod.Slot
local BindRegistry = bind_mod.BindRegistry
local PlayerStore = player_context.PlayerStore
local Offset = geometry.Offset
local OverlayHost = overlay_host.OverlayHost
local Demo = demo_mod.Demo
local PlayerScaffold = player.PlayerScaffold

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

F.test('hiding a retained layer clears hover as well as capture and regions', function()
    mp_stub.reset()
    local host = OverlayHost()
    local layer = host:create('hover', button_root('hover', function() end), {
        z_policy = 'popup',
        input_policy = 'interactive',
    })
    host:render()
    local region = layer.owner:pointer_regions()[1]
    local node = region.node
    local point = Offset(
        (region.rect.left + region.rect.right) / 2,
        (region.rect.top + region.rect.bottom) / 2)
    host.input_router:dispatch_pointer_result('move', point)
    F.ok(node.hovered, 'layer is hovered before hide')
    host:hide('hover')
    F.ok(not node.hovered, 'hide clears the hovered node')
    F.eq(#host.input_router:pointer_regions(), 0, 'hide clears input regions')
    host:shutdown()
end)

F.test('input policy transition makes a modal exclusive without remounting', function()
    mp_stub.reset()
    local lower_clicks = 0
    local host = OverlayHost()
    local lower = host:create('lower', button_root('lower', function()
        lower_clicks = lower_clicks + 1
    end), {
        z_policy = 'main',
        input_policy = 'interactive',
    })
    local modal = host:create('modal', Text('modal'), {
        z_policy = 'popup',
        input_policy = 'passive',
    })
    host:render()
    local lower_state = lower.binding.root_element.state
    local region = lower.owner:pointer_regions()[1]
    local point = Offset(
        (region.rect.left + region.rect.right) / 2,
        (region.rect.top + region.rect.bottom) / 2)
    host.input_router:dispatch_pointer_result('down', point, 'left')
    host.input_router:dispatch_pointer_result('up', point, 'left')
    F.eq(lower_clicks, 1, 'passive modal allows lower click')

    local modal_element = modal.binding.root_element
    F.ok(host:set_input_policy('modal', 'exclusive'), 'modal policy changes')
    F.ok(modal.binding.root_element == modal_element, 'modal remains mounted')
    F.eq(host.input_router:pointer_regions()[1].layer_id, 'modal',
        'exclusive modal owns the full viewport region')
    host.input_router:dispatch_pointer_result('down', point, 'left')
    host.input_router:dispatch_pointer_result('up', point, 'left')
    F.eq(lower_clicks, 1, 'exclusive modal blocks lower click')
    F.ok(lower.binding.root_element.state == lower_state, 'lower State is retained')

    F.raises(function()
        host:set_input_policy('modal', 'unknown' --[[@as any]])
    end, 'overlay input_policy', 'invalid policy is rejected')
    host:shutdown()
end)

F.test('pointer move and leave callbacks do not add a click-claiming section', function()
    mp_stub.reset()
    local moves, leaves = 0, 0
    local host = OverlayHost({
        on_pointer_move = function() moves = moves + 1 end,
        on_pointer_leave = function() leaves = leaves + 1 end,
    })
    host:create('passive', Text('passive'), {
        input_policy = 'passive',
    })
    ---@type { cb: fun(name: any, mouse: table?) }
    local move_event
    for _, event in ipairs(fake.events) do
        if event.name == 'mouse-pos' then
            move_event = event
        end
    end
    fake.mouse = { x = 10, y = 10, hover = true }
    move_event.cb(nil, fake.mouse)
    move_event.cb(nil, nil)
    F.eq(moves, 1, 'move callback receives in-window movement')
    F.eq(leaves, 1, 'leave callback receives window exit')
    F.ok(fake.binding_sections['elxosc-input'] ~= nil, 'normal input section remains defined')
    F.ok(fake.binding_sections['elxosc-showhide'] == nil,
        'no separate click-claiming showhide section is installed')
    host:shutdown()
end)

F.test('compact demo controls stay inside the grid cell and remain interactive', function()
    mp_stub.reset()
    local host = OverlayHost()
    local layer = host:create('demo', PlayerScaffold({
        middle_child = Demo({ compact = true }),
    }), {
        z_policy = 'main',
        input_policy = 'interactive',
    })
    host:render()
    local regions = layer.owner:pointer_regions()
    F.eq(#regions, 6, 'compact demo exports all six controls')
    local width, height = host.display.width, host.display.height
    for _, region in ipairs(regions) do
        F.ok(region.rect.left >= 0 and region.rect.top >= 0,
            'demo region starts inside the viewport')
        F.ok(region.rect.right <= width and region.rect.bottom <= height,
            'demo region remains clipped to the viewport')
        local point = Offset(
            (region.rect.left + region.rect.right) / 2,
            (region.rect.top + region.rect.bottom) / 2)
        host.input_router:dispatch_pointer_result('down', point, 'left')
        host.input_router:dispatch_pointer_result('up', point, 'left')
    end
    F.ok(fake.props['user-data/elxosc-demo-event'] ~= nil,
        'a compact demo control handles input')
    host:shutdown()
end)

F.test('moving outside interactive regions clears button hover state', function()
    mp_stub.reset()
    local host = OverlayHost()
    host:create('main', Column({
        children = {
            button_root('first', function() end),
            button_root('second', function() end),
        },
    }), {
        z_policy = 'main',
        input_policy = 'interactive',
    })
    host:render()

    local regions = host.registry:get('main').owner:pointer_regions()
    F.ok(#regions >= 2, 'two button input regions are installed')
    local first_region = regions[1]
    local second_region = regions[2]
    local first = first_region.node
    local second = second_region.node
    local first_point = Offset(
        (first_region.rect.left + first_region.rect.right) / 2,
        (first_region.rect.top + first_region.rect.bottom) / 2)
    host.input_router:dispatch_pointer_result('move', first_point)
    F.ok(first.hovered, 'first button enters hover')
    F.ok(not second.hovered, 'second button is not hovered')

    host.input_router:dispatch_pointer_result('move', Offset(500, 500))
    F.ok(not first.hovered, 'first button leaves hover in the gap')
    F.ok(not second.hovered, 'second button remains unhovered')
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
