-- Player Shell visibility, Provider lifecycle, and control composition.

---@diagnostic disable: undefined-field, inject-field, need-check-nil, generic-constraint-mismatch, preferred-local-alias, unused

local F = require('framework')
local std = require('elxlibs.std')

local constraints_mod = require('layout.constraints')
local render_owner = require('render.render_owner')
local text_layout = require('text.text_layout')
local binding_mod = require('widget.binding')
local player_context = require('widget.player_context')
local basic_widgets = require('widget.widgets.basic')
local player = require('player')
local scaffold_mod = require('player.scaffold')
local shell_mod = require('player.shell')
local ass_canvas = require('backends.ass_canvas')

local Constraints = constraints_mod.Constraints
local RenderOwner = render_owner.RenderOwner
local WidgetBinding = binding_mod.WidgetBinding
local PlayerScope = player_context.PlayerScope
local PlayerStore = player_context.PlayerStore
local Button = basic_widgets.OutlinedButton
local Text = basic_widgets.Text
local PlayerScaffold = scaffold_mod.PlayerScaffold
local ShellConfig = shell_mod.ShellConfig
local ShellVisibilityController = shell_mod.ShellVisibilityController
local PlayerShell = shell_mod.PlayerShell
local AssCanvas = ass_canvas.AssCanvas

local FixedLayout = std.class.new('test.PlayerShellLayout', { text_layout.TextLayout })
function FixedLayout:line_width(line, style)
    return #line * style.font_size * 0.5
end
text_layout.set_default(FixedLayout())

local function mount(store, mode, controller)
    local scaffold = PlayerScaffold({ middle_child = Text('body') })
    local root = PlayerScope({
        store = store,
        child = PlayerShell({
            scaffold = scaffold,
            controller = controller,
            title_bar = Button({ label = 'control', on_click = function() end }),
        }),
    })
    local owner = RenderOwner()
    local binding = WidgetBinding(root, owner)
    owner:set_viewport(Constraints.tight(500, 300))
    owner:layout()
    return owner, binding
end

local function refresh(owner, binding)
    binding:flush_build()
    owner:layout()
end

local function shell_element(binding)
    return binding.root_element.child.child
end

local function paint_text(owner)
    local canvas = AssCanvas()
    owner:mark_needs_paint()
    owner:paint(canvas)
    return canvas:text()
end

F.section('player shell: visibility and lifecycle')

F.test('aggregate and direct Shell exports preserve identity', function()
    F.eq(player.PlayerShell, PlayerShell, 'PlayerShell identity')
    F.eq(player.ShellConfig, ShellConfig, 'ShellConfig identity')
    F.eq(player.ShellVisibilityController, ShellVisibilityController,
        'visibility controller identity')
end)

F.test('ShellConfig validates closed visibility modes and defaults to auto', function()
    F.eq(ShellConfig().controls_visibility, 'auto', 'default mode')
    F.eq(ShellConfig({ controls_visibility = 'always' }).controls_visibility,
        'always', 'always mode')
    F.eq(ShellConfig({ controls_visibility = 'never' }).controls_visibility,
        'never', 'never mode')
    F.raises(function()
        ---@diagnostic disable-next-line: param-type-mismatch
        ShellConfig({ controls_visibility = 'sometimes' })
    end, 'controls_visibility must be auto, always, or never', 'invalid mode')
end)

F.test('always shows controls and never removes their paint and input regions', function()
    local store = PlayerStore({ controls_visibility = 'always' })
    local owner, binding = mount(store)
    F.ok(#owner:pointer_regions() > 0, 'always exposes a control input region')
    F.contains(paint_text(owner), 'control', 'always paints the control')
    binding:dispose()

    store = PlayerStore({ controls_visibility = 'never' })
    owner, binding = mount(store)
    F.eq(#owner:pointer_regions(), 0, 'never removes control input regions')
    F.ok(not paint_text(owner):find('control', 1, true), 'never removes control paint')
    F.contains(paint_text(owner), 'body', 'hidden controls keep the player content')
    binding:dispose()
end)

F.test('auto transitions on pointer move and leave without remounting State', function()
    local controller = ShellVisibilityController()
    local store = PlayerStore({ controls_visibility = 'auto' })
    local owner, binding = mount(store, nil, controller)
    local element = shell_element(binding)
    local state = element.state
    F.eq(#owner:pointer_regions(), 0, 'auto starts hidden')

    controller:pointer_move()
    refresh(owner, binding)
    F.ok(#owner:pointer_regions() > 0, 'pointer move shows controls')
    F.ok(state == element.state, 'pointer transition keeps Shell State')

    controller:pointer_leave()
    refresh(owner, binding)
    F.eq(#owner:pointer_regions(), 0, 'pointer leave hides controls')
    F.ok(not paint_text(owner):find('control', 1, true), 'pointer leave removes control paint')
    binding:dispose()
end)

F.test('snapshot updates change Shell visibility through Provider rebuild', function()
    local store = PlayerStore({ controls_visibility = 'never' })
    local owner, binding = mount(store)
    local element = shell_element(binding)
    local state = element.state
    F.eq(#owner:pointer_regions(), 0, 'initially hidden')

    store:replace(store:get():copy({ controls_visibility = 'always' }))
    refresh(owner, binding)
    F.ok(#owner:pointer_regions() > 0, 'snapshot update shows controls')
    F.ok(state == element.state, 'Provider update reuses Shell State')

    store:replace(store:get():copy({ controls_visibility = 'never' }))
    refresh(owner, binding)
    F.eq(#owner:pointer_regions(), 0, 'second snapshot update hides controls')
    binding:dispose()
end)

F.test('controller subscriptions are disposed with Shell State', function()
    local controller = ShellVisibilityController()
    local store = PlayerStore({ controls_visibility = 'auto' })
    local owner, binding = mount(store, nil, controller)
    F.eq(#controller._subscriptions, 1, 'one Shell subscription')
    binding:dispose()
    F.eq(#controller._subscriptions, 0, 'dispose removes Shell subscription')
    controller:pointer_move()
end)
