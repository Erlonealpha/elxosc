-- Player text controls with local click state and direct hover visuals.

---@namespace elxosc
---@using elxosc
---@using elxosc.player

local std = require 'elxlibs.std'
local geometry = require 'src.foundation.geometry'
local widget_mod = require 'src.widgets.framework'

local Offset = geometry.Offset
local StatefulWidget = widget_mod.StatefulWidget
local widget_state_mod = require 'src.widgets.state'
local State = widget_state_mod.State
local PlayerSelectorState = require('player.src.context').PlayerSelectorState

local raise = std.raise
local HoverText = require('src.widgets.hover_text').HoverText
local data_mod = require 'player.src.data'
local format_time = data_mod.format_time
local ambient_mod = require 'src.widgets.ambient'
local text_layout_mod = require 'src.text.text_layout'

---@class mod.player.src.text_controls
local M = {}

---@class player.PlayerTimeWidth : std.object
---@field private _layout TextLayout?
---@field private _style TextStyle?
---@field private _widths table<string, number>
---@overload fun(): self
local PlayerTimeWidth = std.class.new('PlayerTimeWidth')

function PlayerTimeWidth:__init()
    self._widths = {}
    self._layout = nil
    self._style = nil
end

--- Candidate digit runs provide a stable reservation; every real shaped label
--- is checked too, so this never claims a font-independent digit upper bound.
---@param layout TextLayout
---@param label string
---@param style TextStyle
---@return number
function PlayerTimeWidth:resolve(layout, label, style)
    local template = label:gsub('%d', '#')
    if not rawequal(self._layout, layout)
        or self._style == nil or self._style.font_family ~= style.font_family
        or self._style.font_size ~= style.font_size or self._style.bold ~= style.bold
        or self._style.italic ~= style.italic or self._style.letter_spacing ~= style.letter_spacing then
        self._layout = layout
        self._style = style
        self._widths = {}
    end
    local width = self._widths[template]
    if width == nil then
        -- Real time labels have few format/sign/suffix templates. Keep the
        -- helper bounded even when an extension supplies arbitrary labels.
        local count = 0
        for _ in pairs(self._widths) do
            count = count + 1
        end
        if count >= 32 or #template > 4096 then
            self._widths = {}
        end
        width = 0
        for digit = 0, 9 do
            local candidate = label:gsub('%d', tostring(digit))
            width = math.max(width, layout:line_width(candidate, style))
        end
    end
    width = math.max(width, layout:line_width(label, style))
    if #template <= 4096 then
        self._widths[template] = width
    end
    return width
end

---@alias player.PlayerTimeToggleMode
--- | 'milliseconds'
--- | 'remaining'

---@alias player.PlayerHoverText HoverText
---@alias player._PlayerHoverTextOptions _HoverTextOptions

---@class player._PlayerTimeDisplayOptions
---@field selector PlayerSelectorFunction?
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

---@class player.PlayerTimeDisplay : StatefulWidget
---@field selector PlayerSelectorFunction?
---@field equals? fun(left: any?, right: any?): boolean
---@field value number?
---@field duration number?
---@field show_remaining boolean
---@field show_milliseconds boolean
---@field _time_width PlayerTimeWidth
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
    self.selector = options.selector
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

---@class player.PlayerTimeDisplayState : PlayerSelectorState
---@field show_remaining boolean
---@field show_milliseconds boolean
---@overload fun(): self
local PlayerTimeDisplayState = std.class.new('PlayerTimeDisplayState', PlayerSelectorState)

function PlayerTimeDisplayState:init_state()
    local widget = self.widget --[[@as PlayerTimeDisplay]]
    self.show_remaining = widget.show_remaining
    self.show_milliseconds = widget.show_milliseconds
    self._time_width = PlayerTimeWidth()
end

---@param old_widget PlayerTimeDisplay
function PlayerTimeDisplayState:did_update_widget(old_widget)
    PlayerSelectorState.did_update_widget(self, old_widget)
    local widget = self.widget --[[@as PlayerTimeDisplay]]
    if old_widget.show_remaining ~= widget.show_remaining then
        self.show_remaining = widget.show_remaining
    end
    if old_widget.show_milliseconds ~= widget.show_milliseconds then
        self.show_milliseconds = widget.show_milliseconds
    end
end

function PlayerTimeDisplayState:build(context)
    local widget = self.widget --[[@as PlayerTimeDisplay]]
    local value = widget.value
    if widget.selector then
        self:read_selection(context)
        value = self.selected
    end
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
    local scope = ambient_mod.TextLayoutScope.maybe_of(context)
    local layout = scope and scope.layout or text_layout_mod.get_default()
    local width = layout and self._time_width:resolve(layout, label, widget.style) or 0
    return HoverText({
        text = label,
        style = widget.style,
        alignment = widget.alignment,
        min_width = width,
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
M.PlayerTimeWidth = PlayerTimeWidth

return M
