local std = require 'elxlibs.std'
local base = require 'widget.widgets.button_base'
local color = require 'foundation.color'
local geometry = require 'foundation.geometry'
local ButtonBase = base.ButtonBase
local ButtonStyle = base.ButtonStyle
local copy_options = base.copy_options
local Color = color.Color
local EdgeInsets = geometry.EdgeInsets
---@class _IconButtonOptions : _ButtonBaseOptions
---@field icon Widget?
---@field radius number?

---@class IconButton : ButtonBase
---@overload fun(options: _IconButtonOptions?): IconButton
local IconButton = std.class.new('IconButton', { ButtonBase })
---@param options _IconButtonOptions?
---@return nil
function IconButton:__init(options)
    options = options or {}
    local config = copy_options(options)
    config.child = config.child or config.icon
    config.style = config.style or ButtonStyle({
        foreground_color = Color.rgba255(235, 235, 235),
        hover_color = Color.rgba255(55, 55, 55),
        pressed_color = Color.rgba255(75, 75, 75),
        radius = config.radius or 20,
        padding = config.padding or EdgeInsets.all(8),
    })
    ButtonBase.__init(self, config)
end
return { IconButton = IconButton }
