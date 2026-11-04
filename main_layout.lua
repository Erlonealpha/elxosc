-- Default player composition: one DefaultApp with explicit Main, Extension and
-- WindowLayer boundaries.  `app.extension` is the only Define content slot;
-- shell and root replacement targets are intentionally not exposed here. Demo
-- content is supplied by the entry point rather than hidden in this module.

local app_mod = require 'widget.player.app'
local slot_mod = require 'widget.slot'
local navigation_mod = require 'widget.navigation'
local layout_widgets = require 'widget.widgets.layout'

local DefaultApp = app_mod.DefaultApp
local Main = app_mod.Main
local WindowLayer = app_mod.WindowLayer
local Container = layout_widgets.Container
local SizedBox = layout_widgets.SizedBox
local SlotSpec = slot_mod.SlotSpec
local SlotWrap = slot_mod.SlotWrap
local CompositionAssembler = slot_mod.CompositionAssembler
local Navigator = navigation_mod.Navigator

local M = {}

---@param extension Widget?
---@param pages Page[]?
---@return Widget
local function build_description(extension, pages)
    local extension_slot_spec = SlotSpec({
        id = 'app.extension',
        allow = { 'set', 'replace' },
        default_op = 'set',
    })
    local extension_slot = Container({
        child = extension or SizedBox.shrink(),
    })
    local window_layer = WindowLayer({
        child = Container({
            child = Navigator({ pages = pages or {} }),
        }),
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
        main = Main({ title = 'elxosc', scale = 1.5 }),
        extension = SlotWrap(extension_slot_spec, extension_slot),
        window_layer = window_layer,
    })
    return app
end

---@param extension Widget?
---@param pages Page[]?
---@return Widget
function M.build_app(extension, pages)
    local root = build_description(extension, pages)
    local app = CompositionAssembler():assemble(root)
    return app
end

---@param extension Widget?
---@param pages Page[]?
---@return Widget
function M.build_app_description(extension, pages)
    return build_description(extension, pages)
end

return M
