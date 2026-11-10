-- Player visual defaults over the standard in-tree Tooltip.

local std = require 'elxlibs.std'
local tooltip_mod = require 'widget.widgets.tooltip'
local text_style_mod = require 'text.text_style'
local color_mod = require 'foundation.color'

local Tooltip = tooltip_mod.Tooltip
local TextStyle = text_style_mod.TextStyle
local Color = color_mod.Color

local default_style = TextStyle({
    font_size = 18,
    color = Color.rgba255(255, 255, 255),
    outline_width = 0.5,
    outline_color = Color.rgba255(0, 0, 0),
    blur_radius = 1,
    wrap = false,
})

---@class _PlayerTooltipOptions : _TooltipOptions

---@class PlayerTooltip : Tooltip
---@overload fun(options?: _PlayerTooltipOptions): self
local PlayerTooltip = std.class.new('PlayerTooltip', Tooltip)

function PlayerTooltip:__init(options)
    local config = {}
    for name, value in pairs(options or {}) do
        config[name] = value
    end
    config.style = config.style or default_style
    Tooltip.__init(self, config)
end

---@class elxosc.widget.player.tooltip
local M = { PlayerTooltip = PlayerTooltip }

return M
