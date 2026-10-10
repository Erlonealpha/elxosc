local std = require 'elxlibs.std'
---@diagnostic disable: undefined-field, generic-constraint-mismatch, param-type-mismatch
local base = require 'widget.widgets.button_base'
local color = require 'foundation.color'
local geometry = require 'foundation.geometry'
local ButtonBase, ButtonStyle = base.ButtonBase, base.ButtonStyle
local Color = color.Color
local IconButton = std.class.new('IconButton', { ButtonBase })
function IconButton:__init(options)
    options = options or {}
    options.child = options.child or options.icon
    options.style = options.style or ButtonStyle({ foreground_color = Color.rgba255(235, 235, 235), hover_color = Color.rgba255(55, 55, 55), pressed_color = Color.rgba255(75, 75, 75), radius = options.radius or 20, padding = options.padding or geometry.EdgeInsets.all(8) })
    ButtonBase.__init(self, options)
end
return { IconButton = IconButton }
