-- Real-host fixture for the backend-neutral text anchor and icon contracts.
-- It keeps the framework tree and the ASS presenter in the loop, then asks
-- libass/mpv to compute bounds for the emitted events.
---@diagnostic disable: call-non-callable, undefined-field, need-check-nil

local mp = require 'mp'
mp.set_property('user-data/elxosc-anchor-loaded', 'yes')

local scripts = mp.command_native({ 'expand-path', '~~/scripts' })
package.path = package.path .. ';' .. scripts .. '/?.lua;' .. scripts .. '/?/init.lua'
    .. ';' .. scripts .. '/elxosc/?.lua;' .. scripts .. '/elxosc/?/init.lua'
package.loaded.elxlib = assert(loadfile(scripts .. '/elxlib/init.lua'))('elxlib')

local geometry = require 'foundation.geometry'
local anchor_mod = require 'foundation.anchor'
local text_paint_mod = require 'painting.text_paint'
local text_style = require 'text.text_style'
local app_mod = require 'host.mpv_app'
local constraints_mod = require 'layout.constraints'
local layout = require 'widget.widgets.layout'
local basic = require 'widget.widgets.basic'

local Offset = geometry.Offset
local Anchor = anchor_mod.Anchor
local TextPaint = text_paint_mod.TextPaint
local TextStyle = text_style.TextStyle
local Constraints = constraints_mod.Constraints
local Column = layout.Column
local Icon = basic.Icon
local Text = basic.Text

local app = app_mod.start(function()
    return Column({
        main_alignment = 'start',
        cross_alignment = 'start',
        children = {
            Text('center anchor', {
                style = TextStyle({ font_size = 24, wrap = false }),
                text_paint = TextPaint({ anchor = Anchor.CENTER, offset = Offset(1, 0) }),
            }),
            Text('bottom-right anchor', {
                style = TextStyle({ font_size = 18, wrap = false }),
                text_paint = TextPaint({ anchor = Anchor.BOTTOM_RIGHT }),
            }),
            Icon('play_arrow', { size = 24, optical_offset = Offset(1, -1) }),
        },
    })
end)

local width, height = 640, 360
app.owner:set_viewport(Constraints.tight(width, height))
app.display.width, app.display.height, app.display.initialized = width, height, true
app:render()

local function publish(name, value)
    mp.set_property('user-data/elxosc-anchor-' .. name, tostring(value))
end

publish('ready', app.canvas.events and #app.canvas.events == 3 and 'yes' or 'no')
publish('ass', app.canvas:text())

local function compute(event, id)
    local ok, result = pcall(mp.command_native, {
        _name = 'osd-overlay',
        id = id,
        format = 'ass-events',
        data = event,
        res_x = width,
        res_y = height,
        compute_bounds = true,
    })
    if not ok or type(result) ~= 'table' then
        return nil
    end
    return result
end

for index, event in ipairs(app.canvas.events) do
    local bounds = compute(event, 9100 + index)
    local prefix = 'bounds-' .. index .. '-'
    if bounds then
        for _, name in ipairs({ 'x0', 'x1', 'y0', 'y1' }) do
            publish(prefix .. name, bounds[name] or 'missing')
        end
    else
        publish(prefix .. 'x0', 'missing')
        publish(prefix .. 'x1', 'missing')
        publish(prefix .. 'y0', 'missing')
        publish(prefix .. 'y1', 'missing')
    end
end
