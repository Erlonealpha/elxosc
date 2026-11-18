-- Host-independent, in-tree hover tooltip.
--
-- The tooltip is deliberately rendered inside the existing Widget tree. It
-- does not create a second overlay or depend on mpv cursor APIs: the wrapping
-- GestureDetector owns only hover state while the wrapped control keeps its
-- normal click/capture behavior.

---@namespace elxosc
---@using elxosc

local std = require 'elxlibs.std'
local geometry = require 'src.foundation.geometry'
local text_style_mod = require 'src.text.text_style'
local widget_mod = require 'src.widgets.framework'
local state_mod = require 'src.widgets.state'
local gesture_mod = require 'src.widgets.gesture_detector'
local custom_paint_mod = require 'src.widgets.custom_paint'
local stack_mod = require 'src.widgets.stack'
local positioned_mod = require 'src.widgets.positioned'
local text_layout_mod = require 'src.text.text_layout'
local ambient_mod = require 'src.widgets.ambient'
local text_paint_mod = require 'src.painting.text_paint'
local anchor_mod = require 'src.foundation.anchor'

local Offset = geometry.Offset
local Rect = geometry.Rect
local TextStyle = text_style_mod.TextStyle
local GestureDetector = gesture_mod.GestureDetector
local CustomPaint = custom_paint_mod.CustomPaint
local Stack = stack_mod.Stack
local Positioned = positioned_mod.Positioned
local StatefulWidget = widget_mod.StatefulWidget
local State = state_mod.State
local max = math.max
local raise = std.raise

---@class mod.src.widgets.tooltip
local M = {}
local default_style = TextStyle({ wrap = false })

local function coordinate(value, name, non_negative)
    if value ~= nil and (type(value) ~= 'number' or value ~= value
        or value == math.huge or value == -math.huge or non_negative and value < 0) then
        raise(std.ValueError('Tooltip.' .. name .. ' must be finite'
            .. (non_negative and ' and non-negative' or '')))
    end
    return value
end

---@class _TooltipOptions
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
---@field hover_enabled (fun(context: BuildContext): boolean)?
---@field paint_for_point (fun(canvas: Canvas, offset: Offset, point: Offset, label: string))?
---@field width_for_text (fun(layout: TextLayout, label: string, style: TextStyle): number)? optional stable visual width
---@field key any?

---@class Tooltip : StatefulWidget
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
---@field hover_enabled (fun(context: BuildContext): boolean)?
---@field paint_for_point (fun(canvas: Canvas, offset: Offset, point: Offset, label: string))?
---@field width_for_text (fun(layout: TextLayout, label: string, style: TextStyle): number)?
---@overload fun(options?: _TooltipOptions): self
local Tooltip = std.class.new('Tooltip', StatefulWidget)

function Tooltip:__init(options)
    options = options or {}
    self.key = options.key
    self.child = options.child
    self.text = options.text or ''
    self.disabled_text = options.disabled_text or ''
    self.text_for_point = options.text_for_point
    self.enabled = options.enabled ~= false
    self.style = options.style or default_style
    self.offset_x = coordinate(options.offset_x or 0, 'offset_x')
    self.offset_y = coordinate(options.offset_y or 0, 'offset_y')
    self.follow_pointer = options.follow_pointer == true
    self.bounds_width = coordinate(options.bounds_width, 'bounds_width', true)
    self.bounds_height = coordinate(options.bounds_height, 'bounds_height', true)
    self.anchor_left = coordinate(options.anchor_left or 0, 'anchor_left')
    self.anchor_top = coordinate(options.anchor_top or 0, 'anchor_top')
    self.anchor_width = coordinate(options.anchor_width, 'anchor_width', true)
    self.anchor_height = coordinate(options.anchor_height, 'anchor_height', true)
    self.margin = coordinate(options.margin == nil and 12 or options.margin, 'margin', true)
    self.gap = coordinate(options.gap == nil and 0 or options.gap, 'gap', true)
    self.position_for_point = options.position_for_point
    self.expand = coordinate(options.expand or 0, 'expand', true)
    self.on_hover_point = options.on_hover_point
    self.on_hover_leave = options.on_hover_leave
    self.hover_enabled = options.hover_enabled
    if self.hover_enabled ~= nil and type(self.hover_enabled) ~= 'function' then
        raise(std.TypeError('Tooltip.hover_enabled must be a function'))
    end
    self.paint_for_point = options.paint_for_point
    self.width_for_text = options.width_for_text
    if self.width_for_text ~= nil and type(self.width_for_text) ~= 'function' then
        raise(std.TypeError('Tooltip.width_for_text must be a function'))
    end
end

---@class TooltipState : State
---@field hovered boolean
---@field hover_label string
---@field hover_point Offset?
---@field _paragraph Paragraph?
---@field _paragraph_label string?
---@field _paragraph_style TextStyle?
---@field _text_layout TextLayout?
---@field _text_generation integer?
---@field _hover_enabled boolean
---@field _prepare_callback fun()
---@field _prepare_owner RenderOwner?
---@field _paragraph_width number?
---@overload fun(): self
local TooltipState = std.class.new('TooltipState', State)

function TooltipState:init_state()
    self.hovered = false
    self.hover_label = ''
    self.hover_point = nil
    self._hover_enabled = true
    self._prepare_callback = function()
        self:_prepare_text()
    end
    self:refresh_hover_visibility()
end

function TooltipState:did_change_dependencies()
    local scope = ambient_mod.TextLayoutScope.maybe_of(assert(self.context))
    local layout = scope and scope.layout or text_layout_mod.get_default()
    local generation = scope and scope.generation or 0
    if not rawequal(self._text_layout, layout) or self._text_generation ~= generation then
        self._text_layout = layout
        self._text_generation = generation
        self._paragraph = nil
        self:_invalidate_paint()
    end
end

-- Upper layers can cancel hover resources without changing child input capture.
function TooltipState:refresh_hover_visibility()
    local widget = self.widget --[[@as Tooltip]]
    local visible = not widget.hover_enabled or widget.hover_enabled(assert(self.context))
    self._hover_enabled = visible
    if not visible then
        self:_clear_hover()
    end
end

function TooltipState:_hover_allowed()
    return self._hover_enabled
end

function TooltipState:did_update_widget(old_widget)
    local old = old_widget --[[@as Tooltip]]
    local widget = self.widget --[[@as Tooltip]]
    if self.hovered and old.on_hover_point and not widget.on_hover_point then
        self:_clear_hover(old)
    end
    self:refresh_hover_visibility()
    if old.width_for_text ~= widget.width_for_text then
        self._paragraph = nil
    end
    self:_schedule_text()
end

---@return string
function TooltipState:_label()
    local widget = self.widget --[[@as Tooltip]]
    if widget.text_for_point and self.hover_label ~= '' then
        return self.hover_label
    end
    if widget.enabled then
        return widget.text
    end
    return widget.disabled_text ~= '' and widget.disabled_text or widget.text
end

function TooltipState:dispose()
    self:_clear_hover()
    if self._prepare_owner then
        self._prepare_owner:cancel_prepare(self._prepare_callback)
    end
    self._prepare_owner = nil
end

---@param previous Tooltip?
function TooltipState:_clear_hover(previous)
    local widget = previous or self.widget --[[@as Tooltip]]
    if self.hovered and widget.on_hover_leave then
        widget.on_hover_leave()
    end
    self.hovered = false
    self.hover_label = ''
    self.hover_point = nil
    self:_invalidate_paint()
end

function TooltipState:_invalidate_paint()
    local render_object = self.context and self.context:first_render_object()
    if render_object then
        render_object:mark_needs_paint()
    end
    self:_schedule_text()
end

function TooltipState:_schedule_text()
    local widget = self.widget --[[@as Tooltip]]
    local label = self:_label()
    if not self.hovered or not self:_hover_allowed() or label == '' then
        if self._prepare_owner then
            self._prepare_owner:cancel_prepare(self._prepare_callback)
        end
        return
    end
    if self._paragraph and self._paragraph_label == label and self._paragraph_style == widget.style then
        if self._prepare_owner then
            self._prepare_owner:cancel_prepare(self._prepare_callback)
        end
        return
    end
    local owner = self.context and self.context.owner and self.context.owner.render_owner
    if owner then
        if self._prepare_owner and self._prepare_owner ~= owner then
            self._prepare_owner:cancel_prepare(self._prepare_callback)
        end
        self._prepare_owner = owner
        owner:schedule_prepare(self._prepare_callback)
    end
end

function TooltipState:_prepare_text()
    if not self:is_mounted() or not self.hovered or not self:_hover_allowed() then
        return
    end
    local widget = self.widget --[[@as Tooltip]]
    local label = self:_label()
    local measurer = self._text_layout or text_layout_mod.get_default()
    if label == '' or measurer == nil then
        self._paragraph = nil
        return
    end
    local paragraph = measurer:layout(label, widget.style, math.huge)
    local width = paragraph.size.width
    if widget.width_for_text then
        width = widget.width_for_text(measurer, label, widget.style)
    end
    if type(width) ~= 'number' or width < 0 or width ~= width or width == math.huge then
        raise(std.ValueError('Tooltip.width_for_text must return a finite non-negative width'))
    end
    self._paragraph = paragraph
    self._paragraph_label = label
    self._paragraph_style = widget.style
    self._paragraph_width = max(width, paragraph.size.width)
end

---@param canvas Canvas
---@param offset Offset
---@param size Size
function TooltipState:_paint_tooltip(canvas, offset, size)
    local widget = self.widget --[[@as Tooltip]]
    local label = self:_label()
    if self.hovered and self:_hover_allowed() and label ~= '' then
        if widget.paint_for_point and self.hover_point then
            widget.paint_for_point(canvas, offset, self.hover_point, label)
        end
        local paragraph = self._paragraph
        if paragraph == nil or self._paragraph_label ~= label or self._paragraph_style ~= widget.style then
            return
        end
        local visual_width = self._paragraph_width or paragraph.size.width
        local available_width = widget.bounds_width
            and max(0, widget.bounds_width - widget.margin * 2) or visual_width
        local width = math.min(visual_width, available_width)
        local height = paragraph.size.height
        local anchor_left = widget.anchor_left or 0
        local anchor_top = widget.anchor_top or 0
        local anchor_width = widget.anchor_width or size.width
        local anchor_height = widget.anchor_height or size.height
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

function TooltipState:build()
    -- Every rebuild clears old inherited registrations; keep the service
    -- dependency subscribed even when only the parent Widget changed.
    self:did_change_dependencies()
    local widget = self.widget --[[@as Tooltip]]
    local children = {}
    if widget.child then
        children[1] = widget.child
    end
    children[#children + 1] = Positioned({
        left = 0, top = 0, right = 0, bottom = 0,
        child = CustomPaint({
            draw = function(canvas, offset, size)
                self:_paint_tooltip(canvas, offset, size)
            end,
        }),
    })
    return GestureDetector(Stack({ children = children }), {
        expand = widget.expand,
        on_enter = function()
            if self:_hover_allowed() and not self.hovered then
                self.hovered = true
                self:_invalidate_paint()
            end
        end,
        on_leave = function()
            if self.hovered then
                self:_clear_hover()
            end
        end,
        on_hover_move = function(_, point)
            if not self:_hover_allowed() then
                return
            end
            if not self.hovered then
                self.hovered = true
                self:_invalidate_paint()
            end
            if widget.follow_pointer or widget.text_for_point
                or widget.on_hover_point or widget.paint_for_point then
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

function Tooltip:create_state()
    return TooltipState()
end

M.Tooltip = Tooltip

return M
