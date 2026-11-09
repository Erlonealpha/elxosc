-- Append-only player control slots: assembly, scaled input and public buttons.
---@namespace test.playerextensions
---@diagnostic disable: undefined-field, inject-field, need-check-nil, unused

local F = require 'framework'
local std = require 'elxlibs.std'
local text_layout = require 'text.text_layout'
local geometry = require 'foundation.geometry'
local Constraints = require('layout.constraints').Constraints
local RenderOwner = require('render.render_owner').RenderOwner
local WidgetBinding = require('widget.binding').WidgetBinding
local WidgetsApp = require('widget.app').WidgetsApp
local DisplaySnapshot = require('widget.ambient').DisplaySnapshot
local PlayerScope = require('widget.player_context').PlayerScope
local PlayerStore = require('widget.player_context').PlayerStore
local ContributionRegistry = require('widget.slot').ContributionRegistry
local CompositionAssembler = require('widget.slot').CompositionAssembler
local extension_mod = require 'widget.player.extension_controls'
local geometry_for = require('widget.player.geometry').geometry_for
local main_layout = require 'main_layout'
local PlayerControlBar = extension_mod.PlayerControlBar
local PlayerControlButton = extension_mod.PlayerControlButton

---@class ExtensionTextLayout : TextLayout
---@overload fun(): self
local ExtensionTextLayout = std.class.new('ExtensionTextLayout', text_layout.TextLayout)
function ExtensionTextLayout:line_width(line, style)
    return #line * style.font_size * 0.5
end
text_layout.set_default(ExtensionTextLayout())

F.section('player extensions')

F.test('aggregates expose the same public control classes and options stay immutable', function()
    F.eq(require('widget.player').PlayerControlBar, PlayerControlBar, 'player bar identity')
    F.eq(require('widget').PlayerControlButton, PlayerControlButton, 'DSL button identity')
    local children = { PlayerControlButton({ icon = 'toggle_on' }) }
    local bar = PlayerControlBar({ children = children })
    children[2] = PlayerControlButton({ icon = 'toggle_off' })
    F.eq(bar:control_count(), 1, 'constructor copies caller children')
    F.raises(function()
        ---@diagnostic disable-next-line: param-type-mismatch
        PlayerControlBar({ children = { false } })
    end, 'must contain Widgets', 'non-widget controls are rejected')
end)

F.test('both slots append across scopes in registration order and reject replacement', function()
    local registry = ContributionRegistry()
    for _, side in ipairs({ 'left', 'right' }) do
        registry:add('player.controls.' .. side, PlayerControlButton({ key = side .. '-a', icon = 'toggle_on' }),
            { op = 'append' }, 'first')
        registry:add('player.controls.' .. side, PlayerControlButton({ key = side .. '-b', icon = 'toggle_off' }),
            { op = 'append' }, 'second')
        registry:add('player.controls.' .. side, PlayerControlButton({ icon = 'science' }),
            { op = 'replace' }, 'rejected')
    end
    registry:add('player.controls.extra_right_control', PlayerControlButton({ icon = 'science' }),
        { op = 'set' }, 'old-slot')
    local root, diagnostics = CompositionAssembler(registry:seal()):assemble(main_layout.build_app_description())
    F.eq(#diagnostics, 3, 'both replacements and the removed slot are rejected')
    F.eq(root.main.left_controls.children[1].key, 'left-a', 'first left contribution stays leftmost')
    F.eq(root.main.left_controls.children[2].key, 'left-b', 'second left contribution appends inward')
    F.eq(root.main.right_controls.children[1].key, 'right-b', 'second right contribution appends inward')
    F.eq(root.main.right_controls.children[2].key, 'right-a', 'first right contribution stays nearest pin')
    F.eq(main_layout.build_app().main.left_controls:control_count(), 0, 'empty left slot reserves no cells')
    F.eq(main_layout.build_app().main.right_controls:control_count(), 0, 'empty right slot reserves no cells')
end)

F.test('extension geometry fits around built-ins and collapses without overlap', function()
    for _, profile in ipairs({ 'original', 'reduced' }) do
        local base = geometry_for(profile, 1280, 720, { info_button = true })
        local extra = geometry_for(profile, 1280, 720, {
            left_control_count = 2, right_control_count = 2, info_button = true,
        })
        F.eq(extra.right.fullscreen, base.right.fullscreen, 'fullscreen stays at the edge')
        F.eq(extra.right.ontop, base.right.ontop, 'pin position stays fixed')
        F.eq(extra.right.right_controls:width(), 69, 'two fixed 24px cells have 45px steps')
        F.eq(extra.right.info.left, base.right.info.left - 90, 'later right controls move by two cells')
        F.eq(extra.side.left_controls.left, extra.volume.right + 21, 'left group clears the volume slider')
        F.ok(extra.visibility.left_controls and extra.visibility.right_controls, 'wide viewport shows both groups')
        local narrow = geometry_for(profile, 300, 180, { left_control_count = 4, right_control_count = 4 })
        F.ok(not narrow.visibility.left_controls and not narrow.visibility.right_controls,
            'narrow viewport hides groups before they intersect central buttons')
        local compact_base = geometry_for(profile, 300, 180, {})
        F.eq(narrow.visibility.fullscreen, compact_base.visibility.fullscreen,
            'a hidden extension group preserves built-in visibility')
        local empty = geometry_for(profile, 1280, 720, { left_control_count = 0, right_control_count = 0 })
        F.eq(empty.side.left_controls, nil, 'no left contribution has no geometry')
        F.eq(empty.right.right_controls, nil, 'no right contribution has no geometry')
    end
    for _, count in ipairs({ -1, 0.5, math.huge, 0 / 0 }) do
        F.raises(function()
            geometry_for('original', 1280, 720, { left_control_count = count })
        end, 'PlayerLayout.left_control_count', 'invalid count is rejected')
    end
end)

F.test('scaled left and right buttons receive separate clicks and disabled buttons ignore clicks', function()
    local registry = ContributionRegistry()
    local clicked = {}
    for _, side in ipairs({ 'left', 'right' }) do
        for index = 1, 2 do
            local key = side .. index
            registry:add('player.controls.' .. side, PlayerControlButton({
                key = key, icon = 'toggle_on', enabled = key ~= 'left2',
                on_click = function()
                    clicked[#clicked + 1] = key
                end,
            }), { op = 'append' }, key)
        end
    end
    local root = CompositionAssembler(registry:seal()):assemble(main_layout.build_app_description())
    local owner = RenderOwner()
    local binding = WidgetBinding.ensure_initialized():attach(WidgetsApp({
        display = DisplaySnapshot({ width = 1920, height = 1080, initialized = true }),
        child = PlayerScope({ store = PlayerStore({ idle_active = false }), child = root }),
    }), owner)
    owner:set_viewport(Constraints.tight(1920, 1080))
    owner:layout()
    local layout = geometry_for('original', 1280, 720, { left_control_count = 2, right_control_count = 2 })
    local y = (layout.side.left_controls.top + 12) * 1.5
    for _, x in ipairs({ layout.side.left_controls.left + 12, layout.side.left_controls.left + 57,
        layout.right.right_controls.left + 12, layout.right.right_controls.left + 57 }) do
        local point = geometry.Offset(x * 1.5, y)
        owner:dispatch_pointer('move', point)
        owner:dispatch_pointer('down', point, 'left')
        owner:dispatch_pointer('up', point, 'left')
    end
    F.eq(table.concat(clicked, ','), 'left1,right2,right1', 'scale maps clicks into separate enabled cells')
    binding:dispose()
end)
