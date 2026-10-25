-- Default player composition: one DefaultApp with explicit Main, Extension and
-- WindowLayer boundaries.  Demo content is supplied by the entry point rather
-- than being hidden inside this application-layer module.

local app_mod = require 'widget.app'
local basic_widgets = require 'widget.widgets.basic'
local layout_widgets = require 'widget.widgets.layout'

local DefaultApp = app_mod.DefaultApp
local Main = app_mod.Main
local WindowLayer = app_mod.WindowLayer
local Text = basic_widgets.Text
local Container = layout_widgets.Container
local SizedBox = layout_widgets.SizedBox

local M = {}

---@param extension Widget?
---@return Widget
function M.build_app(extension)
    local title_bar = Container({
        id = 'title_bar',
        child = Text('elxosc'),
    })
    local window_controls = Container({
        id = 'window_controls',
        child = SizedBox.shrink(),
    })
    local bottom = Container({
        id = 'bottom_controls',
        child = SizedBox.shrink(),
    })
    local extension_slot = Container({
        id = 'extension',
        child = extension or SizedBox.shrink(),
    })
    local window_layer = WindowLayer({
        child = Container({
            id = 'window_layer',
            child = SizedBox.shrink(),
        }),
    })

    return DefaultApp({
        title = 'elxosc',
        main = Main({
            title = 'elxosc',
            title_bar = title_bar,
            window_controls = window_controls,
            bottom = bottom,
        }),
        extension = extension_slot,
        window_layer = window_layer,
    })
end

return M
