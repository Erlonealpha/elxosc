-- Player visual defaults over the standard in-tree Tooltip.

local std = require 'elxlibs.std'
local tooltip_mod = require 'src.widgets.tooltip'
local text_style_mod = require 'src.text.text_style'
local color_mod = require 'src.foundation.color'
local AutoHide = require('player.src.auto_hide').AutoHide

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

---@class elxosc.player._PlayerTooltipOptions : _TooltipOptions

---@class elxosc.player.PlayerTooltip : Tooltip
---@overload fun(options?: elxosc.player._PlayerTooltipOptions): self
local PlayerTooltip = std.class.new('PlayerTooltip' --[[@as 'elxosc.player.PlayerTooltip']], Tooltip)

function PlayerTooltip:__init(options)
    local config = {}
    for name, value in pairs(options or {}) do
        config[name] = value
    end
    config.style = config.style or default_style
    local hover_enabled = config.hover_enabled
    config.hover_enabled = function(context)
        local ancestor = context.parent
        while ancestor do
            if std.isinstance(ancestor.widget, AutoHide) and not ancestor.widget.controller.visible then
                return false
            end
            ancestor = ancestor.parent
        end
        return not hover_enabled or hover_enabled(context)
    end
    Tooltip.__init(self, config)
end

---@class elxosc.mod.player.src.tooltip
local M = { PlayerTooltip = PlayerTooltip }

return M
