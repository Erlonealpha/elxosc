-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Wraps a subtree and turns raw pointer events into taps / wheel / hover
-- (Flutter's `GestureDetector`).
--
-- The host routes events through `RenderOwner:dispatch_pointer`; this node is
-- the usual terminal handler laid over a drawn box. `expand` grows the hit
-- area beyond the child's bounds, which is how small controls get a forgiving
-- target without changing what is drawn.

local std = require 'elxlibs.std'
local geometry = require 'foundation.geometry'
local render_object = require 'render.render_object'

local Offset = geometry.Offset
local Rect = geometry.Rect
local Size = geometry.Size
local RenderObject = render_object.RenderObject

local M = {}

---@class GestureHandlers
---@field expand number? extra hit area in px on every side
---@field on_enter fun(self: RenderGesture)?
---@field on_leave fun(self: RenderGesture)?
---@field on_move fun(self: RenderGesture, point: Offset, event: PointerEvent?)?
---@field on_down fun(self: RenderGesture, point: Offset, event: PointerEvent?)?
---@field on_up fun(self: RenderGesture, point: Offset, event: PointerEvent?)?
---@field on_tap fun(self: RenderGesture, point: Offset, event: PointerEvent?)?
---@field on_click fun(self: RenderGesture, point: Offset, event: PointerEvent?)? alias for on_tap
---@field on_button_down (fun(self: RenderGesture, button: PointerButton?, point: Offset?, event: PointerEvent?): boolean?)?
---@field on_button_up (fun(self: RenderGesture, button: PointerButton?, point: Offset?, event: PointerEvent?): boolean?)?
---@field on_state_change fun(self: RenderGesture)? called after hovered/pressed changes
---@field on_wheel (fun(self: RenderGesture, delta: number, event: PointerEvent?): boolean?)?
---@field initial_hovered boolean? state to restore when a widget rebuilds
---@field initial_pressed boolean? state to restore when a widget rebuilds

---@class RenderGesture : RenderObject
---@field handlers GestureHandlers
---@field hovered boolean
---@field pressed boolean
---@field _last_pointer_event PointerEvent?
---@field _initial_state_sync boolean
---@overload fun(child: RenderObject?, handlers: GestureHandlers?): self
local RenderGesture = std.class.new('RenderGesture', RenderObject)

function RenderGesture:__init(child, handlers)
    std.super(RenderGesture, self, RenderObject).__init(self)
    self.handlers = handlers or {}
    self.hovered = self.handlers.initial_hovered == true
    self.pressed = self.handlers.initial_pressed == true
    self._last_pointer_event = nil
    self._initial_state_sync = true
    if child then
        self:adopt_child(child)
    end
end

function RenderGesture:__perform_layout(constraints)
    local child = self._children[1]
    if child then
        child:layout(constraints)
        child.parent_data.offset = Offset.zero()
        self.size = child.size
    else
        self.size = constraints:constrain_size(Size(0, 0))
    end
    if self._initial_state_sync then
        self._initial_state_sync = false
        local callback = self.handlers.on_state_change
        if callback then
            callback(self)
        end
    end
end

---@param handlers GestureHandlers
function RenderGesture:set_handlers(handlers)
    local down, wheel = self:wants_pointer('down'), self:wants_pointer('wheel')
    local expand = self.handlers.expand or 0
    self.handlers = handlers
    if down ~= self:wants_pointer('down') or wheel ~= self:wants_pointer('wheel')
        or expand ~= (handlers.expand or 0) then
        self:mark_needs_input()
    end
    if not self:wants_pointer('down') then
        self.pressed = false
    end
    self:mark_needs_paint()
    if handlers.on_state_change then
        handlers.on_state_change(self)
    end
end

function RenderGesture:_notify_state_change()
    self:mark_needs_paint()
    local callback = self.handlers.on_state_change
    if callback then
        callback(self)
    end
end

function RenderGesture:__hit_test_bounds(point)
    local expand = self.handlers.expand or 0
    return point.x >= -expand and point.y >= -expand
        and point.x < self.size.width + expand and point.y < self.size.height + expand
end

---@param event PointerEvent
---@param point Offset?
---@return boolean|DispatchResult|nil
function RenderGesture:on_pointer_event(event, point)
    self._last_pointer_event = event
    local result = RenderObject.on_pointer_event(self, event, point)
    self._last_pointer_event = nil
    return result
end

---@return Rect
function RenderGesture:input_region_rect()
    local expand = self.handlers.expand or 0
    return Rect(-expand, -expand, self.size.width + expand, self.size.height + expand)
end

function RenderGesture:wants_pointer(event)
    local h = self.handlers
    if event == 'down' or event == 'up' then
        return h.on_down ~= nil or h.on_up ~= nil or h.on_tap ~= nil or h.on_click ~= nil
            or h.on_button_down ~= nil or h.on_button_up ~= nil
    elseif event == 'wheel' then
        return h.on_wheel ~= nil
    elseif event == 'move' then
        return h.on_move ~= nil or h.on_enter ~= nil or h.on_leave ~= nil
    end
    return false
end

---@param data any?
---@return boolean
local function is_primary_button(data)
    return data == nil or data == 'left'
end

function RenderGesture:on_pointer(event, point, data)
    local h = self.handlers
    if event == 'down' then
        if not is_primary_button(data) then
            if h.on_button_down then
                return h.on_button_down(self, data, point, self._last_pointer_event) ~= false
            end
            return false
        end
        local pointer = self._last_pointer_event
        local modifiers = pointer and pointer.modifiers
        if h.on_button_down then
            h.on_button_down(self, data or 'left', point, pointer)
        end
        if modifiers and modifiers.shift then
            return h.on_button_down ~= nil
        end
        self.pressed = true
        if h.on_down and point ~= nil then
            h.on_down(self, point, pointer)
        end
        self:_notify_state_change()
        return h.on_down ~= nil or h.on_up ~= nil or h.on_tap ~= nil or h.on_click ~= nil
    elseif event == 'up' then
        if not is_primary_button(data) then
            if h.on_button_up then
                return h.on_button_up(self, data, point, self._last_pointer_event) ~= false
            end
            return false
        end
        local pointer = self._last_pointer_event
        if h.on_button_up then
            h.on_button_up(self, data or 'left', point, pointer)
        end
        if pointer and pointer.modifiers and pointer.modifiers.shift then
            return h.on_button_up ~= nil
        end
        local was_pressed = self.pressed
        self.pressed = false
        if point ~= nil then
            if h.on_up then
                h.on_up(self, point, pointer)
            end
            if was_pressed and h.on_tap then
                h.on_tap(self, point, pointer)
            end
            if was_pressed and h.on_click then
                h.on_click(self, point, pointer)
            end
        end
        self:_notify_state_change()
        return was_pressed
    elseif event == 'cancel' then
        self.pressed = false
        self:_notify_state_change()
        return false
    elseif event == 'wheel' then
        if h.on_wheel then
            return h.on_wheel(self, data, self._last_pointer_event) ~= false
        end
        return false
    elseif event == 'enter' then
        self.hovered = true
        if h.on_enter then
            h.on_enter(self)
        end
        self:_notify_state_change()
        return false
    elseif event == 'leave' then
        if self.hovered then
            self.hovered = false
            if h.on_leave then
                h.on_leave(self)
            end
        end
        self:_notify_state_change()
        return false
    elseif event == 'move' then
        if h.on_move and point ~= nil then
            h.on_move(self, point, self._last_pointer_event)
        end
        return false
    end
    return false
end

M.RenderGesture = RenderGesture

return M
