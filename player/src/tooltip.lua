-- Player visual defaults over the standard in-tree Tooltip.

---@namespace elxosc
---@using elxosc
---@using elxosc.player

local std = require 'elxlibs.std'
local tooltip_mod = require 'src.widgets.tooltip'
local text_style_mod = require 'src.text.text_style'
local color_mod = require 'src.foundation.color'
local auto_hide_mod = require 'player.src.auto_hide'
local time_mod = require 'player.src.text_controls'
local widget_mod = require 'src.widgets.framework'
local state_mod = require 'src.widgets.state'

local AutoHide = auto_hide_mod.AutoHide

local pairs = pairs

local Tooltip = tooltip_mod.Tooltip
local TextStyle = text_style_mod.TextStyle
local Color = color_mod.Color

local default_style = TextStyle({
    font_size = 18,
    color = Color.rgba255(255, 255, 255),
    outline_width = 0.5,
    outline_color = Color.rgba255(0, 0, 0),
    blur_radius = 1,
    wrap = false
})

---@class player._PlayerTooltipOptions: _TooltipOptions

---@class player.PlayerTooltip: Tooltip
---@overload fun(options?: _PlayerTooltipOptions): self
local PlayerTooltip = std.class.new('PlayerTooltip', Tooltip)

---@param options _PlayerTooltipOptions?
function PlayerTooltip:__init(options)
    local config = {}
    for name, value in pairs(options or {}) do
        config[name] = value
    end
    config.style = config.style or default_style
    local hover_enabled = config.hover_enabled
    config.hover_enabled = function (context)
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

---@class mod.player.src.tooltip
local M = {
    PlayerTooltip = PlayerTooltip
}

---@class player.PlayerTimeTooltip: StatefulWidget
---@field config _PlayerTooltipOptions
---@overload fun(options?: _PlayerTooltipOptions): self
local PlayerTimeTooltip = std.class.new('PlayerTimeTooltip', widget_mod.StatefulWidget)

---@param options _PlayerTooltipOptions?
function PlayerTimeTooltip:__init(options)
    self.key = options and options.key
    self.config = {}
    for name, value in pairs(options or {}) do
        self.config[name] = value
    end
end

---@class player.PlayerTimeTooltipState: State
---@field _width          PlayerTimeWidth
---@field _width_for_text fun(layout: TextLayout, label: string, style: TextStyle): number
---@overload fun(): self
local PlayerTimeTooltipState = std.class.new('PlayerTimeTooltipState', state_mod.State)

function PlayerTimeTooltipState:init_state()
    self._width = time_mod.PlayerTimeWidth()
    self._width_for_text = function (layout, label, style)
        return self._width:resolve(layout, label, style)
    end
end

---@return Widget?
function PlayerTimeTooltipState:build()
    local widget = self.widget --[[@as PlayerTimeTooltip]]
    local config = {}
    for name, value in pairs(widget.config) do
        config[name] = value
    end
    config.width_for_text = self._width_for_text
    return PlayerTooltip(config)
end

---@return PlayerTimeTooltipState
function PlayerTimeTooltip:create_state()
    return PlayerTimeTooltipState()
end

M.PlayerTimeTooltip = PlayerTimeTooltip

return M
