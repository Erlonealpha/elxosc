-- Default player composition: one DefaultApp with explicit Main, Extension and
-- WindowLayer boundaries.  Demo content is supplied by the entry point rather
-- than being hidden inside this application-layer module.

local app_mod = require 'widget.app'
local slot_mod = require 'widget.slot'
local basic_widgets = require 'widget.widgets.basic'
local layout_widgets = require 'widget.widgets.layout'

local DefaultApp = app_mod.DefaultApp
local Main = app_mod.Main
local WindowLayer = app_mod.WindowLayer
local Text = basic_widgets.Text
local Container = layout_widgets.Container
local SizedBox = layout_widgets.SizedBox
local SlotSpec = slot_mod.SlotSpec
local SlotWrap = slot_mod.SlotWrap
local CompositionAssembler = slot_mod.CompositionAssembler

local M = {}

---@param extension Widget?
---@return Widget
local function build_description(extension)
    local title_bar_slot = SlotSpec({
        id = 'app.title_bar',
        allow = { 'set', 'replace' },
        default_op = 'set',
    })
    local window_controls_slot = SlotSpec({
        id = 'app.window_controls',
        allow = { 'set', 'replace' },
        default_op = 'set',
    })
    local bottom_slot = SlotSpec({
        id = 'app.bottom_controls',
        allow = { 'set', 'replace' },
        default_op = 'set',
    })
    local extension_slot_spec = SlotSpec({
        id = 'app.extension',
        allow = { 'set', 'replace' },
        default_op = 'set',
    })
    local window_layer_slot = SlotSpec({
        id = 'app.window_layer',
        allow = { 'set', 'replace' },
        default_op = 'set',
    })
    local app_slot = SlotSpec({
        id = 'app',
        allow = { 'replace' },
        default_op = 'replace',
    })
    local title_bar = Container({
        child = Text('elxosc'),
    })
    local window_controls = Container({
        child = SizedBox.shrink(),
    })
    local bottom = Container({
        child = SizedBox.shrink(),
    })
    local extension_slot = Container({
        child = extension or SizedBox.shrink(),
    })
    local window_layer = WindowLayer({
        child = Container({
            child = SizedBox.shrink(),
        }),
    })

    local app = DefaultApp({
        title = 'elxosc',
        main = Main({
            title = 'elxosc',
            title_bar = SlotWrap(title_bar_slot, title_bar),
            window_controls = SlotWrap(window_controls_slot, window_controls),
            bottom = SlotWrap(bottom_slot, bottom),
        }),
        extension = SlotWrap(extension_slot_spec, extension_slot),
        window_layer = SlotWrap(window_layer_slot, window_layer),
    })
    return SlotWrap(app_slot, app)
end

---@param extension Widget?
---@return Widget
function M.build_app(extension)
    local root = build_description(extension)
    local app = CompositionAssembler():assemble(root)
    return app
end

---@param extension Widget?
---@return Widget
function M.build_app_description(extension)
    return build_description(extension)
end

return M
