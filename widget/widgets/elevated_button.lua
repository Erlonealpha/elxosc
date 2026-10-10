local std = require 'elxlibs.std'
---@diagnostic disable: undefined-field, generic-constraint-mismatch, param-type-mismatch
local base = require 'widget.widgets.button_base'
local color = require 'foundation.color'
local ButtonBase, ButtonStyle = base.ButtonBase, base.ButtonStyle
local Color = color.Color
local ElevatedButton = std.class.new('ElevatedButton', { ButtonBase })
function ElevatedButton:__init(options)
    options = options or {}
    options.style = options.style or ButtonStyle({ background_color = Color.rgba255(55, 95, 160), hover_color = Color.rgba255(70, 110, 180), pressed_color = Color.rgba255(40, 75, 130), elevation = 2 })
    ButtonBase.__init(self, options)
end
return { ElevatedButton = ElevatedButton }
