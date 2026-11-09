-- Default player composition: one DefaultApp with explicit Main, Extension and
-- WindowLayer boundaries. Define exposes extension content and appended controls
-- in the bottom left/right button bars;
-- shell and root replacement targets are intentionally not exposed here.
-- Development content uses the same Define slot as other extensions.

local app_mod = require 'widget.player.app'
local slot_mod = require 'widget.slot'
local layout_widgets = require 'widget.widgets.layout'
local extension_controls_mod = require 'widget.player.extension_controls'

local DefaultApp = app_mod.DefaultApp
local Main = app_mod.Main
local WindowLayer = app_mod.WindowLayer
local Container = layout_widgets.Container
local SizedBox = layout_widgets.SizedBox
local SlotSpec = slot_mod.SlotSpec
local SlotWrap = slot_mod.SlotWrap
local CompositionAssembler = slot_mod.CompositionAssembler
local PlayerControlBar = extension_controls_mod.PlayerControlBar

local M = {}

---@alias PlayerControlSide
---| 'left'
---| 'right'

---@param side PlayerControlSide
---@return SlotWrap
local function control_slot(side)
    return SlotWrap(SlotSpec({
        id = 'player.controls.' .. side,
        allow = { 'append' }, default_op = 'append', default_value = {},
        builder = function(value)
            local children = {}
            ---@type Widget[]
            local buttons = value
            for index = 1, #buttons do
                local source_index = side == 'right' and #buttons - index + 1 or index
                children[index] = buttons[source_index]
            end
            return PlayerControlBar({ children = children })
        end,
    }))
end

---@return Widget
local function build_description()
    local extension_slot_spec = SlotSpec({
        id = 'app.extension',
        allow = { 'set', 'replace' },
        default_op = 'set',
    })
    local extension_slot = Container({
        child = SizedBox.shrink(),
    })
    local window_layer = WindowLayer({
        child = SlotWrap(SlotSpec({
            id = 'app.window_layer',
            allow = { 'set', 'replace' }, default_op = 'set',
        }), SizedBox.shrink()),
    })

    local app = DefaultApp({
        title = 'elxosc',
        auto_hide_bottom_hover = true,
        auto_hide_hover_zone = 175,
        auto_hide_top_hover = true,
        auto_hide_top_hover_zone = 40,
        auto_hide_fade_duration = 0.15,
        -- ModernX's default OSC scale is 1.5 in both windowed and fullscreen
        -- modes.  Keep this player entrypoint explicit without changing the
        -- generic framework ThemeData default.
        main = Main({
            title = 'elxosc', scale = 1.5,
            left_controls = control_slot('left'),
            right_controls = control_slot('right'),
        }),
        extension = SlotWrap(extension_slot_spec, extension_slot),
        window_layer = window_layer,
    })
    return app
end

---@return Widget
function M.build_app()
    local root = build_description()
    local app = CompositionAssembler():assemble(root)
    return app
end

---@return Widget
function M.build_app_description()
    return build_description()
end

return M
