-- Small, player-owned hover tooltip.
--
-- The tooltip is deliberately rendered inside the existing Widget tree. It
-- does not create a second overlay or depend on mpv cursor APIs: the wrapping
-- GestureDetector owns only hover state while the wrapped control keeps its
-- normal click/capture behavior.

local std = require 'elxlibs.std'
local geometry = require 'foundation.geometry'
local color_mod = require 'foundation.color'
local text_style_mod = require 'text.text_style'
local widget_mod = require 'widget.widget'
local state_mod = require 'widget.state'
local basic_widgets = require 'widget.widgets.basic'
local layout_widgets = require 'widget.widgets.layout'
local decorated_mod = require 'widget.widgets.decorated_box'

local Offset = geometry.Offset
local EdgeInsets = geometry.EdgeInsets
local Color = color_mod.Color
local TextStyle = text_style_mod.TextStyle
local GestureDetector = basic_widgets.GestureDetector
local Text = basic_widgets.Text
local Container = layout_widgets.Container
local Positioned = layout_widgets.Positioned
local Stack = layout_widgets.Stack
local Decoration = decorated_mod.Decoration
local StatefulWidget = widget_mod.StatefulWidget
local State = state_mod.State

local M = {}

---@class _PlayerTooltipOptions
---@field child Widget?
---@field text string?
---@field disabled_text string?
---@field text_for_point (fun(point: Offset): string?)?
---@field enabled boolean?
---@field style TextStyle?
---@field offset_x number?
---@field offset_y number?
---@field follow_pointer boolean?
---@field bounds_width number?
---@field expand number?
---@field on_hover_point fun(point: Offset, label: string?)?
---@field on_hover_leave fun()?
---@field key any?

---@class PlayerTooltip : StatefulWidget
---@field child Widget?
---@field text string
---@field disabled_text string
---@field text_for_point (fun(point: Offset): string?)?
---@field enabled boolean
---@field style TextStyle
---@field offset_x number
---@field offset_y number
---@field follow_pointer boolean
---@field bounds_width number?
---@field expand number
---@field on_hover_point fun(point: Offset, label: string?)?
---@field on_hover_leave fun()?
---@overload fun(options?: _PlayerTooltipOptions): self
local PlayerTooltip = std.class.new('PlayerTooltip', { StatefulWidget })

function PlayerTooltip:__init(options)
    options = options or {}
    self.key = options.key
    self.child = options.child
    self.text = options.text or ''
    self.disabled_text = options.disabled_text or ''
    self.text_for_point = options.text_for_point
    self.enabled = options.enabled ~= false
    self.style = options.style or TextStyle({
        font_size = 14,
        color = Color.rgba255(255, 255, 255),
        outline_width = 0.5,
        outline_color = Color.rgba255(0, 0, 0),
        wrap = false,
    })
    self.offset_x = options.offset_x == nil and -8 or options.offset_x
    self.offset_y = options.offset_y == nil and -30 or options.offset_y
    self.follow_pointer = options.follow_pointer == true
    self.bounds_width = options.bounds_width
    self.expand = options.expand or 0
    self.on_hover_point = options.on_hover_point
    self.on_hover_leave = options.on_hover_leave
end

---@class PlayerTooltipState : State
---@field hovered boolean
---@field hover_label string
---@field hover_point Offset?
---@overload fun(): self
local PlayerTooltipState = std.class.new('PlayerTooltipState', { State })

function PlayerTooltipState:init_state()
    self.hovered = false
    self.hover_label = ''
    self.hover_point = nil
end

---@return string
function PlayerTooltipState:_label()
    local widget = self.widget --[[@as PlayerTooltip]]
    if widget.text_for_point and self.hover_label ~= '' then
        return self.hover_label
    end
    if widget.enabled then
        return widget.text
    end
    return widget.disabled_text ~= '' and widget.disabled_text or widget.text
end

function PlayerTooltipState:dispose()
    local widget = self.widget --[[@as PlayerTooltip]]
    if self.hovered and widget.on_hover_leave then
        widget.on_hover_leave()
    end
end

function PlayerTooltipState:build()
    local widget = self.widget --[[@as PlayerTooltip]]
    local children = { widget.child }
    local label = self:_label()
    if self.hovered and label ~= '' then
        local left = widget.offset_x
        local top = widget.offset_y
        if widget.follow_pointer and self.hover_point then
            local estimated_width = #label * 8 + 12
            if widget.bounds_width and self.hover_point.x < estimated_width / 2 then
                left = self.hover_point.x + 8 + widget.offset_x
            elseif widget.bounds_width
                and self.hover_point.x > widget.bounds_width - estimated_width / 2 then
                left = self.hover_point.x - estimated_width - 8 + widget.offset_x
            else
                left = self.hover_point.x - estimated_width / 2 + widget.offset_x
            end
            top = self.hover_point.y + widget.offset_y
            if widget.bounds_width then
                left = math.max(0, math.min(left, widget.bounds_width - estimated_width))
            end
        end
        children[#children + 1] = Positioned({
            left = left,
            top = top,
            child = Container({
                padding = EdgeInsets.symmetric(6, 3),
                decoration = Decoration({
                    color = Color.rgba255(0, 0, 0, 230),
                    radius = 3,
                    border_width = 1,
                    border_color = Color.rgba255(255, 255, 255, 70),
                }),
                child = Text(label, { style = widget.style }),
            }),
        })
    end
    return GestureDetector(Stack({ children = children }), {
        expand = widget.expand,
        on_enter = function()
            if not self.hovered then
                self:set_state(function()
                    self.hovered = true
                end)
            end
        end,
        on_leave = function()
            if self.hovered then
                if widget.on_hover_leave then
                    widget.on_hover_leave()
                end
                self:set_state(function()
                    self.hovered = false
                    self.hover_label = ''
                    self.hover_point = nil
                end)
            end
        end,
        on_move = function(_, point)
            if point then
                local label_at_point = widget.text_for_point
                    and (widget.text_for_point(point) or '') or nil
                local changed = self.hover_point == nil
                    or self.hover_point.x ~= point.x
                    or self.hover_point.y ~= point.y
                    or self.hover_label ~= (label_at_point or '')
                if changed then
                    if widget.on_hover_point then
                        widget.on_hover_point(point, label_at_point)
                    end
                    self:set_state(function()
                        self.hovered = true
                        self.hover_label = label_at_point or ''
                        self.hover_point = point
                    end)
                end
            end
        end,
    })
end

function PlayerTooltip:create_state()
    return PlayerTooltipState()
end

M.PlayerTooltip = PlayerTooltip

return M
