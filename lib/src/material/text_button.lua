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
---@class material._TextButtonOptions: material._ButtonBaseOptions

---@class material.TextButton: material.ButtonBase
---@overload fun(options: _TextButtonOptions?): self
local TextButton = std.class.new('TextButton', ButtonBase)
---@param options _TextButtonOptions?
function TextButton:__init(options)
    options = options or {}
    local config = copy_options(options)
    config.style = config.style
        or ButtonStyle({
            foreground_color = Color.rgba255(90, 165, 240),
            hover_color = Color.rgba255(30, 45, 65),
            pressed_color = Color.rgba255(40, 60, 85),
            padding = config.padding
        })
    ButtonBase.__init(self, config)
end
---@class mod.src.material.text_button
local M = {
    TextButton = TextButton
}

return M
