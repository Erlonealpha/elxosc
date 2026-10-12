-- Real-host fixture for the pure-paint and layout-affecting scale boxes.
---@diagnostic disable: call-non-callable, undefined-field, need-check-nil

local mp = require 'mp'
mp.set_property('user-data/elxosc-transform-loaded', 'yes')

local scripts = mp.command_native({ 'expand-path', '~~/scripts' })
package.path = package.path .. ';' .. scripts .. '/?.lua;' .. scripts .. '/?/init.lua'
    .. ';' .. scripts .. '/elxosc/?.lua;' .. scripts .. '/elxosc/?/init.lua'
package.loaded.elxlib = assert(loadfile(scripts .. '/elxlib/init.lua'))('elxlib')

local geometry = require 'foundation.geometry'
local text_style = require 'text.text_style'
local app_mod = require 'host.mpv_app'
local constraints_mod = require 'layout.constraints'
local layout = require 'widget.widgets.layout'
local basic = require 'widget.widgets.basic'

local Size = geometry.Size
local TextStyle = text_style.TextStyle
local Constraints = constraints_mod.Constraints
local TransformBox = layout.TransformBox
local LayoutScaleBox = layout.LayoutScaleBox
local SizedBox = layout.SizedBox
local Row = layout.Row
local Text = basic.Text

local app = app_mod.start(function()
    return Row({
        spacing = 12,
        children = {
            TransformBox(SizedBox({
                width = 220,
                height = 80,
                child = Text('real host transform', {
                    style = TextStyle({ font_size = 24, wrap = false }),
                }),
            }), {
                scale = Size(1.25, 0.8),
                clip = true,
            }),
            LayoutScaleBox(Text('real host layout scale', {
                style = TextStyle({ font_size = 24, wrap = false }),
            }), {
                scale = Size(1.2, 1.1),
                clip = true,
            }),
        },
    })
end)

local width, height = 640, 360
app.owner:set_viewport(Constraints.tight(width, height))
app.display.width, app.display.height, app.display.initialized = width, height, true
app:render()

mp.set_property('user-data/elxosc-transform-ready', #app.canvas.events >= 2 and 'yes' or 'no')
mp.set_property('user-data/elxosc-transform-ass', app.canvas:text())

local ok, bounds = pcall(mp.command_native, {
    _name = 'osd-overlay',
    id = 9202,
    format = 'ass-events',
    data = app.canvas:text(),
    res_x = width,
    res_y = height,
    compute_bounds = true,
})
if ok and type(bounds) == 'table' then
    for _, name in ipairs({ 'x0', 'x1', 'y0', 'y1' }) do
        mp.set_property('user-data/elxosc-transform-bounds-' .. name, tostring(bounds[name] or 'missing'))
    end
else
    for _, name in ipairs({ 'x0', 'x1', 'y0', 'y1' }) do
        mp.set_property('user-data/elxosc-transform-bounds-' .. name, 'missing')
    end
end
