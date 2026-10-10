local std = require 'elxlibs.std'
---@diagnostic disable: undefined-field, generic-constraint-mismatch, param-type-mismatch
local base = require 'widget.widgets.button_base'
local color = require 'foundation.color'
local ButtonBase, ButtonStyle = base.ButtonBase, base.ButtonStyle
local Color = color.Color
local TextButton = std.class.new('TextButton', { ButtonBase })
function TextButton:__init(options)
    options = options or {}
    options.style = options.style or ButtonStyle({ foreground_color = Color.rgba255(90, 165, 240), hover_color = Color.rgba255(30, 45, 65), pressed_color = Color.rgba255(40, 60, 85), padding = options.padding })
    ButtonBase.__init(self, options)
end
return { TextButton = TextButton }
