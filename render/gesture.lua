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
local Size = geometry.Size
local RenderObject = render_object.RenderObject

local M = {}

---@class GestureHandlers
---@field expand number? extra hit area in px on every side
---@field on_enter fun(self: RenderGesture)?
---@field on_leave fun(self: RenderGesture)?
---@field on_move fun(self: RenderGesture, point: Offset)?
---@field on_down fun(self: RenderGesture, point: Offset)?
---@field on_up fun(self: RenderGesture, point: Offset)?
---@field on_tap fun(self: RenderGesture, point: Offset)?
---@field on_click fun(self: RenderGesture, point: Offset)? alias for on_tap
---@field on_wheel (fun(self: RenderGesture, delta: number): boolean?)?

---@class RenderGesture : RenderObject
---@field handlers GestureHandlers
---@field hovered boolean
---@field pressed boolean
---@overload fun(child: RenderObject?, handlers: GestureHandlers?): self
local RenderGesture = std.class.new('RenderGesture', { RenderObject })

function RenderGesture:__init(child, handlers)
    std.super(RenderGesture, self, RenderObject).__init(self)
    self.handlers = handlers or {}
    self.hovered = false
    self.pressed = false
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
end

function RenderGesture:__hit_test_bounds(point)
    local expand = self.handlers.expand or 0
    return point.x >= -expand and point.y >= -expand
        and point.x < self.size.width + expand and point.y < self.size.height + expand
end

function RenderGesture:wants_pointer(event)
    local h = self.handlers
    if event == 'down' or event == 'up' then
        return h.on_down ~= nil or h.on_up ~= nil or h.on_tap ~= nil or h.on_click ~= nil
    elseif event == 'wheel' then
        return h.on_wheel ~= nil
    elseif event == 'move' then
        return h.on_move ~= nil or h.on_enter ~= nil or h.on_leave ~= nil
    end
    return false
end

function RenderGesture:on_pointer(event, point, data)
    local h = self.handlers
    if event == 'down' then
        if data == 'right' then
            return false
        end
        self.pressed = true
        if h.on_down and point ~= nil then
            h.on_down(self, point)
        end
        return h.on_down ~= nil or h.on_up ~= nil or h.on_tap ~= nil or h.on_click ~= nil
    elseif event == 'up' then
        if data == 'right' then
            return false
        end
        local was_pressed = self.pressed
        self.pressed = false
        if point ~= nil then
            if h.on_up then
                h.on_up(self, point)
            end
            if was_pressed and h.on_tap then
                h.on_tap(self, point)
            end
            if was_pressed and h.on_click then
                h.on_click(self, point)
            end
        end
        return was_pressed
    elseif event == 'cancel' then
        self.pressed = false
        return false
    elseif event == 'wheel' then
        if h.on_wheel then
            return h.on_wheel(self, data) ~= false
        end
        return false
    elseif event == 'enter' then
        self.hovered = true
        if h.on_enter then
            h.on_enter(self)
        end
        return false
    elseif event == 'leave' then
        if self.hovered then
            self.hovered = false
            if h.on_leave then
                h.on_leave(self)
            end
        end
        return false
    elseif event == 'move' then
        if h.on_move and point ~= nil then
            h.on_move(self, point)
        end
        return false
    end
    return false
end

M.RenderGesture = RenderGesture

return M
