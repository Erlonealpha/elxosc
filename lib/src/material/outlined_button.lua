---@namespace elxosc
---@using elxosc
---@using elxosc.material

local std = require 'elxlibs.std'
local base = require 'src.material.button_base'
local color = require 'src.foundation.color'

local ButtonBase = base.ButtonBase
local ButtonStyle = base.ButtonStyle
local copy_options = base.copy_options
local Color = color.Color

---@class material._OutlinedButtonOptions : material._ButtonBaseOptions

---@class material.OutlinedButton : material.ButtonBase
---@overload fun(options: _OutlinedButtonOptions?): self
local OutlinedButton = std.class.new('OutlinedButton', ButtonBase)
---@param options _OutlinedButtonOptions?
function OutlinedButton:__init(options)
    options = options or {}
    local config = copy_options(options)
    config.style = config.style or ButtonStyle({
        foreground_color = Color.rgba255(80, 150, 230),
        hover_color = Color.rgba255(35, 55, 75),
        pressed_color = Color.rgba255(45, 70, 95),
        border_color = Color.rgba255(80, 150, 230),
        border_width = 1,
    })
    ButtonBase.__init(self, config)
end

---@class mod.src.material.outlined_button
local M = { OutlinedButton = OutlinedButton }

return M
