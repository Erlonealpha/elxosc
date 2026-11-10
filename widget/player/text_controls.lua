-- Player text controls with local click state and direct hover visuals.

local std = require 'elxlibs.std'
local geometry = require 'foundation.geometry'
local widget_mod = require 'widget.widget'

local Offset = geometry.Offset
local StatefulWidget = widget_mod.StatefulWidget
local widget_state_mod = require 'widget.state'
local State = widget_state_mod.State

local raise = std.raise
local HoverText = require('widget.widgets.hover_text').HoverText
local data_mod = require 'widget.player.data'
local format_time = data_mod.format_time

---@class elxosc.widget.player.text_controls
local M = {}

---@alias PlayerTimeToggleMode
--- | 'milliseconds'
--- | 'remaining'

---@alias PlayerHoverText HoverText
---@alias _PlayerHoverTextOptions _HoverTextOptions

---@class _PlayerTimeDisplayOptions
---@field value number?
---@field duration number?
---@field show_remaining boolean?
---@field show_milliseconds boolean?
---@field unicode_minus boolean?
---@field fixed boolean?
---@field toggle_mode PlayerTimeToggleMode
---@field suffix string?
---@field style TextStyle
---@field alignment Offset
---@field hover_color Color?
---@field hover_shadow_color Color?
---@field hover_shadow_radius number?
---@field key any?

---@class PlayerTimeDisplay : StatefulWidget
---@field value number?
---@field duration number?
---@field show_remaining boolean
---@field show_milliseconds boolean
---@field unicode_minus boolean
---@field fixed boolean
---@field toggle_mode PlayerTimeToggleMode
---@field suffix string
---@field style TextStyle
---@field alignment Offset
---@field hover_color Color?
---@field hover_shadow_color Color?
---@field hover_shadow_radius number?
---@overload fun(options: _PlayerTimeDisplayOptions): self
local PlayerTimeDisplay = std.class.new('PlayerTimeDisplay', StatefulWidget)

function PlayerTimeDisplay:__init(options)
    options = options or {}
    self.key = options.key
    self.value = options.value
    self.duration = options.duration
    self.show_remaining = options.show_remaining == true
    self.show_milliseconds = options.show_milliseconds == true
    self.unicode_minus = options.unicode_minus == true
    self.fixed = options.fixed == true
    self.toggle_mode = options.toggle_mode or 'milliseconds'
    if self.toggle_mode ~= 'milliseconds' and self.toggle_mode ~= 'remaining' then
        raise(std.ValueError('PlayerTimeDisplay.toggle_mode is invalid'))
    end
    self.style = options.style
    self.alignment = options.alignment or Offset(0.5, 0.5)
    self.suffix = options.suffix or ''
    self.hover_color = options.hover_color
    self.hover_shadow_color = options.hover_shadow_color
    self.hover_shadow_radius = options.hover_shadow_radius or 0
end

---@class PlayerTimeDisplayState : State
---@field show_remaining boolean
---@field show_milliseconds boolean
---@overload fun(): self
local PlayerTimeDisplayState = std.class.new('PlayerTimeDisplayState', State)

function PlayerTimeDisplayState:init_state()
    local widget = self.widget --[[@as PlayerTimeDisplay]]
    self.show_remaining = widget.show_remaining
    self.show_milliseconds = widget.show_milliseconds
end

function PlayerTimeDisplayState:did_update_widget(old_widget)
    local widget = self.widget --[[@as PlayerTimeDisplay]]
    if old_widget.show_remaining ~= widget.show_remaining then
        self.show_remaining = widget.show_remaining
    end
    if old_widget.show_milliseconds ~= widget.show_milliseconds then
        self.show_milliseconds = widget.show_milliseconds
    end
end

function PlayerTimeDisplayState:build()
    local widget = self.widget --[[@as PlayerTimeDisplay]]
    local value = widget.value
    local prefix = ''
    local label
    if value == nil then
        value = 0
        label = '--:--'
    elseif widget.toggle_mode == 'remaining' then
        if self.show_remaining then
            value = (widget.duration or 0) - value
        else
            value = widget.duration
        end
        if value == nil then
            label = '--:--'
            value = 0
        end
        if self.show_remaining and value > 0 then
            prefix = widget.unicode_minus and '−' or '-'
        else
            value = math.abs(value)
        end
    end
    if label == nil then
        label = prefix .. format_time(value, self.show_milliseconds, widget.fixed)
    end
    label = label .. widget.suffix
    return HoverText({
        text = label,
        style = widget.style,
        alignment = widget.alignment,
        hover_color = widget.hover_color,
        hover_shadow_color = widget.hover_shadow_color,
        hover_shadow_radius = widget.hover_shadow_radius,
        on_tap = function()
            self:set_state(function()
                if widget.toggle_mode == 'remaining' then
                    self.show_remaining = not self.show_remaining
                else
                    self.show_milliseconds = not self.show_milliseconds
                end
            end)
        end,
    })
end

function PlayerTimeDisplay:create_state()
    return PlayerTimeDisplayState()
end

M.PlayerTimeDisplay = PlayerTimeDisplay
M.PlayerHoverText = HoverText

return M
