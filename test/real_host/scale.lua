-- Real-host fixture for the finite ASS scale/clip path.
---@diagnostic disable: call-non-callable, undefined-field, need-check-nil

local mp = require 'mp'
mp.set_property('user-data/elxosc-scale-loaded', 'yes')

local scripts = mp.command_native({ 'expand-path', '~~/scripts' })
package.path = package.path .. ';' .. scripts .. '/?.lua;' .. scripts .. '/?/init.lua'
    .. ';' .. scripts .. '/elxosc/?.lua;' .. scripts .. '/elxosc/?/init.lua'
package.loaded.elxlib = assert(loadfile(scripts .. '/elxlib/init.lua'))('elxlib')

local text_style = require 'text.text_style'
local app_mod = require 'host.mpv_app'
local constraints_mod = require 'layout.constraints'
local layout = require 'widget.widgets.layout'
local basic = require 'widget.widgets.basic'

local TextStyle = text_style.TextStyle
local Constraints = constraints_mod.Constraints
local FittedBox = layout.FittedBox
local Text = basic.Text

local app = app_mod.start(function()
    return FittedBox(Text('real host finite scale', {
        style = TextStyle({ font_size = 32, wrap = false }),
    }), { fit = 'contain', clip = true })
end)

local width, height = 640, 360
app.owner:set_viewport(Constraints.tight(width, height))
app.display.width, app.display.height, app.display.initialized = width, height, true
app:render()

mp.set_property('user-data/elxosc-scale-ready', #app.canvas.events == 1 and 'yes' or 'no')
mp.set_property('user-data/elxosc-scale-ass', app.canvas:text())

local ok, bounds = pcall(mp.command_native, {
    _name = 'osd-overlay',
    id = 9201,
    format = 'ass-events',
    data = app.canvas:text(),
    res_x = width,
    res_y = height,
    compute_bounds = true,
})
if ok and type(bounds) == 'table' then
    for _, name in ipairs({ 'x0', 'x1', 'y0', 'y1' }) do
        mp.set_property('user-data/elxosc-scale-bounds-' .. name, tostring(bounds[name] or 'missing'))
    end
else
    for _, name in ipairs({ 'x0', 'x1', 'y0', 'y1' }) do
        mp.set_property('user-data/elxosc-scale-bounds-' .. name, 'missing')
    end
end
