-- Compatibility entry point for the original Button API.
---@diagnostic disable: undefined-field, generic-constraint-mismatch, param-type-mismatch
local std = require 'elxlibs.std'
local base = require 'widget.widgets.button_base'
local style_mod = require 'widget.widgets.button_style'
local color = require 'foundation.color'

local ButtonBase, ButtonStyle = base.ButtonBase, style_mod.ButtonStyle
local Color = color.Color
local Button = std.class.new('Button', { ButtonBase })
function Button:__init(options)
    options = options or {}
    options.style = options.style or ButtonStyle({
        background_color = Color.rgba255(55, 95, 160),
        hover_color = Color.rgba255(65, 110, 180),
        pressed_color = Color.rgba255(45, 80, 135),
        disabled_color = Color.rgba255(85, 85, 85),
        elevation = 1,
    })
    ButtonBase.__init(self, options)
end
return { Button = Button }
