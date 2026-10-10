local std = require 'elxlibs.std'
---@diagnostic disable: undefined-field, generic-constraint-mismatch, param-type-mismatch
local base = require 'widget.widgets.button_base'
local color = require 'foundation.color'
local ButtonBase, ButtonStyle = base.ButtonBase, base.ButtonStyle
local Color = color.Color
local OutlinedButton = std.class.new('OutlinedButton', { ButtonBase })
function OutlinedButton:__init(options)
    options = options or {}
    options.style = options.style or ButtonStyle({ foreground_color = Color.rgba255(80, 150, 230), hover_color = Color.rgba255(35, 55, 75), pressed_color = Color.rgba255(45, 70, 95), border_color = Color.rgba255(80, 150, 230), border_width = 1 })
    ButtonBase.__init(self, options)
end
return { OutlinedButton = OutlinedButton }
