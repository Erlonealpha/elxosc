local std = require 'elxlibs.std'
local base = require 'widget.widgets.button_base'
local color = require 'foundation.color'

local ButtonBase = base.ButtonBase
local ButtonStyle = base.ButtonStyle
local copy_options = base.copy_options
local Color = color.Color

---@class _ElevatedButtonOptions : _ButtonBaseOptions

---@class ElevatedButton : ButtonBase
---@overload fun(options: _ElevatedButtonOptions?): self
local ElevatedButton = std.class.new('ElevatedButton', { ButtonBase })
---@param options _ElevatedButtonOptions?
function ElevatedButton:__init(options)
    options = options or {}
    local config = copy_options(options)
    config.style = config.style or ButtonStyle({
        background_color = Color.rgba255(55, 95, 160),
        hover_color = Color.rgba255(70, 110, 180),
        pressed_color = Color.rgba255(40, 75, 130),
        elevation = 2,
    })
    ButtonBase.__init(self, config)
end

return { ElevatedButton = ElevatedButton }
