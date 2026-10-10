-- Button construction preserves the caller's configuration and public behavior.

local F = require 'framework'
local geometry = require 'foundation.geometry'
local color_mod = require 'foundation.color'
local pointer_mod = require 'foundation.pointer_event'
local base_mod = require 'widget.widgets.button_base'
local style_mod = require 'widget.widgets.button_style'
local button_mod = require 'widget.widgets.button'
local elevated_mod = require 'widget.widgets.elevated_button'
local outlined_mod = require 'widget.widgets.outlined_button'
local text_mod = require 'widget.widgets.text_button'
local icon_mod = require 'widget.widgets.icon_button'

local Offset = geometry.Offset
local EdgeInsets = geometry.EdgeInsets
local Color = color_mod.Color
local PointerEvent = pointer_mod.PointerEvent
local ButtonBase = base_mod.ButtonBase
local ButtonStyle = style_mod.ButtonStyle

F.section('button: construction contract')

F.test('variant constructors do not change the supplied options', function()
    local variants = {
        button_mod.Button,
        elevated_mod.ElevatedButton,
        outlined_mod.OutlinedButton,
        text_mod.TextButton,
        icon_mod.IconButton,
    }
    local icon = ButtonBase({ label = 'icon' })
    local padding = EdgeInsets.all(3)
    local options = { label = 'Play', icon = icon, padding = padding, radius = 12 }
    for _, Variant in ipairs(variants) do
        local result = Variant(options)
        F.eq(options.style, nil, 'caller style is untouched')
        F.eq(options.child, nil, 'caller child is untouched')
        F.eq(result.label, 'Play', 'label is retained')
        F.ok(result.style ~= nil, 'variant has a style')
    end
    F.eq(options.padding, padding, 'caller padding is retained')
    F.eq(options.icon, icon, 'caller icon is retained')
    F.eq(icon_mod.IconButton(options).child, icon, 'icon supplies the child')
end)

F.test('custom style and explicit child win over defaults', function()
    local style = ButtonStyle({ background_color = Color.rgba255(1, 2, 3) })
    local child = ButtonBase({ label = 'child' })
    local options = { style = style, child = child, icon = ButtonBase() }
    local icon_button = icon_mod.IconButton(options)
    F.eq(icon_button.style, style, 'custom style')
    F.eq(icon_button.child, child, 'explicit child')
    F.eq(options.style, style, 'same caller style')
    local copy = style:copy_with({ radius = 9 })
    F.eq(style.radius, 4, 'copy_with does not change the original')
    F.eq(copy.radius, 9, 'copy_with changes the copy')
end)

F.test('pointer constructors retain positional and extension fields', function()
    local point = Offset(2, 3)
    local positional = PointerEvent('down', point, 'left', { device = 'mouse' })
    F.eq(positional.point, point, 'positional point')
    F.eq(positional.device, 'mouse', 'extension field')
    local fields = { type = 'move', point = point, pressure = 0.5 }
    local from_fields = PointerEvent(fields)
    F.eq(from_fields.type, 'move', 'table event type')
    F.eq(from_fields.pressure, 0.5, 'table extension field')
end)
