-- Compatibility entry point for the original Button API.
local std = require 'elxlibs.std'
local base = require 'widget.widgets.button_base'
local style_mod = require 'widget.widgets.button_style'
local color = require 'foundation.color'

local ButtonBase = base.ButtonBase
local ButtonStyle = style_mod.ButtonStyle
local copy_options = base.copy_options
local Color = color.Color
---@class _ButtonOptions : _ButtonBaseOptions

---@class Button : ButtonBase
---@overload fun(options: _ButtonOptions?): self
local Button = std.class.new('Button', { ButtonBase })
---@param options _ButtonOptions?
function Button:__init(options)
    options = options or {}
    local config = copy_options(options)
    config.style = config.style or ButtonStyle({
        background_color = Color.rgba255(55, 95, 160),
        hover_color = Color.rgba255(65, 110, 180),
        pressed_color = Color.rgba255(45, 80, 135),
        disabled_color = Color.rgba255(85, 85, 85),
        elevation = 1,
    })
    ButtonBase.__init(self, config)
end
return { Button = Button }
