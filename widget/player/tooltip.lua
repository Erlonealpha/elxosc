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
local text_layout_mod = require 'text.text_layout'
local text_paint_mod = require 'painting.text_paint'
local anchor_mod = require 'foundation.anchor'

local Offset = geometry.Offset
local Rect = geometry.Rect
local Color = color_mod.Color
local TextStyle = text_style_mod.TextStyle
local GestureDetector = basic_widgets.GestureDetector
local CustomPaint = basic_widgets.CustomPaint
local Stack = layout_widgets.Stack
local StatefulWidget = widget_mod.StatefulWidget
local State = state_mod.State
local max = math.max

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
---@field bounds_height number?
---@field anchor_left number?
---@field anchor_top number?
---@field anchor_width number?
---@field anchor_height number?
---@field margin number?
---@field gap number?
---@field position_for_point (fun(point: Offset, label: string?): number?)?
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
---@field bounds_height number?
---@field anchor_left number?
---@field anchor_top number?
---@field anchor_width number?
---@field anchor_height number?
---@field margin number
---@field gap number
---@field position_for_point (fun(point: Offset, label: string?): number?)?
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
        font_size = 18,
        color = Color.rgba255(255, 255, 255),
        outline_width = 0.5,
        outline_color = Color.rgba255(0, 0, 0),
        blur_radius = 1,
        wrap = false,
    })
    self.offset_x = options.offset_x or 0
    self.offset_y = options.offset_y or 0
    self.follow_pointer = options.follow_pointer == true
    self.bounds_width = options.bounds_width
    self.bounds_height = options.bounds_height
    self.anchor_left = options.anchor_left or 0
    self.anchor_top = options.anchor_top or 0
    self.anchor_width = options.anchor_width or 0
    self.anchor_height = options.anchor_height or 0
    self.margin = options.margin == nil and 12 or options.margin
    self.gap = options.gap == nil and 0 or options.gap
    self.position_for_point = options.position_for_point
    self.expand = options.expand or 0
    self.on_hover_point = options.on_hover_point
    self.on_hover_leave = options.on_hover_leave
end

---@class PlayerTooltipState : State
---@field hovered boolean
---@field hover_label string
---@field hover_point Offset?
---@field _paragraph Paragraph?
---@field _paragraph_label string?
---@field _paragraph_style TextStyle?
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

function PlayerTooltipState:_invalidate_paint()
    local render_object = self.context and self.context:first_render_object()
    if render_object then
        render_object:mark_needs_paint()
    end
end

---@param canvas Canvas
---@param offset Offset
function PlayerTooltipState:_paint_tooltip(canvas, offset)
    local widget = self.widget --[[@as PlayerTooltip]]
    local label = self:_label()
    if self.hovered and label ~= '' then
        if self._paragraph == nil or self._paragraph_label ~= label
            or self._paragraph_style ~= widget.style then
            local measurer = text_layout_mod.get_default()
            if measurer == nil then
                return
            end
            self._paragraph = measurer:layout(label, widget.style, math.huge)
            self._paragraph_label = label
            self._paragraph_style = widget.style
        end
        local paragraph = self._paragraph
        local available_width = widget.bounds_width
            and max(0, widget.bounds_width - widget.margin * 2) or paragraph.size.width
        local width = math.min(paragraph.size.width, available_width)
        local height = paragraph.size.height
        local anchor_left = widget.anchor_left or 0
        local anchor_top = widget.anchor_top or 0
        local anchor_width = widget.anchor_width or 0
        local anchor_height = widget.anchor_height or 0
        local center_x = anchor_left + anchor_width / 2
        local y = anchor_top - widget.gap + widget.offset_y
        ---@type AnchorName
        local anchor = anchor_mod.Anchor.BOTTOM_CENTER
        if widget.follow_pointer and self.hover_point then
            local point_x = self.hover_point.x
            if widget.position_for_point then
                point_x = widget.position_for_point(self.hover_point, label) or point_x
            end
            center_x = anchor_left + point_x
        end
        center_x = center_x + widget.offset_x
        if widget.bounds_width then
            center_x = max(widget.margin + width / 2,
                math.min(center_x, widget.bounds_width - widget.margin - width / 2))
        end
        if widget.bounds_height then
            if y - height < widget.margin then
                y = anchor_top + anchor_height + widget.gap + widget.offset_y
                anchor = anchor_mod.Anchor.TOP_CENTER
            end
            if anchor == anchor_mod.Anchor.BOTTOM_CENTER then
                y = max(widget.margin + height,
                    math.min(y, widget.bounds_height - widget.margin))
            else
                y = max(widget.margin, math.min(y, widget.bounds_height - widget.margin - height))
            end
        end
        local position = (offset + Offset(center_x - anchor_left, y - anchor_top)) --[[@as Offset]]
        canvas:save()
        local ok, err = pcall(function()
            if paragraph.size.width > width then
                local clip_top = anchor == anchor_mod.Anchor.BOTTOM_CENTER
                    and position.y - height or position.y
                canvas:clip_rect(Rect.from_ltwh(position.x - width / 2, clip_top, width, height))
            end
            canvas:draw_text(paragraph, position, text_paint_mod.TextPaint({ anchor = anchor }))
        end)
        canvas:restore()
        if not ok then
            error(err, 0)
        end
    end
end

function PlayerTooltipState:build()
    local widget = self.widget --[[@as PlayerTooltip]]
    return GestureDetector(Stack({ children = {
        widget.child,
        CustomPaint({
            draw = function(canvas, offset)
                self:_paint_tooltip(canvas, offset)
            end,
        }),
    } }), {
        expand = widget.expand,
        on_enter = function()
            if not self.hovered then
                self.hovered = true
                self:_invalidate_paint()
            end
        end,
        on_leave = function()
            if self.hovered then
                if widget.on_hover_leave then
                    widget.on_hover_leave()
                end
                self.hovered = false
                self.hover_label = ''
                self.hover_point = nil
                self:_invalidate_paint()
            end
        end,
        on_move = function(_, point)
            if point and (widget.follow_pointer or widget.text_for_point) then
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
                    self.hovered = true
                    self.hover_label = label_at_point or ''
                    self.hover_point = point
                    self:_invalidate_paint()
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
