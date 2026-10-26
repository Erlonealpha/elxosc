-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Tree owner: the viewport, the dirty flag and the layout/paint entry points
-- (the single-root `PipelineOwner`; RendererBinding is a shared role facade).
--
-- `on_dirty` is the hook the host backend wires to its frame clock, so a dirty
-- node schedules a frame -- and an idle tree schedules nothing.

local std = require 'elxlibs.std'
local geometry = require 'foundation.geometry'
local constraints_mod = require 'layout.constraints'
local pointer_event = require 'foundation.pointer_event'
local painting_context = require 'render.painting_context'
local region_snapshot = require 'render.region_snapshot'

local Offset = geometry.Offset
local Constraints = constraints_mod.Constraints
local PointerEvent = pointer_event.PointerEvent
local PaintingContext = painting_context.PaintingContext
local RegionSnapshot = region_snapshot.RegionSnapshot
local raise = std.raise
local POINTER_BUTTONS = { left = true, middle = true, right = true }

local M = {}

---@param value boolean?
---@param name string
local function validate_result_field(value, name)
    if value ~= nil and type(value) ~= 'boolean' then
        raise(std.TypeError('DispatchResult.' .. name .. ' must be a boolean'))
    end
end

---@param value any
---@param event PointerEvent
---@return DispatchResult
local function normalize_dispatch_result(value, event)
    if value == nil or value == false then
        return { handled = false, capture = false, stop_propagation = false }
    end
    if value == true then
        return {
            handled = true,
            capture = event.type == 'down',
            stop_propagation = event.type ~= 'move',
        }
    end
    if type(value) ~= 'table' then
        raise(std.TypeError('pointer dispatch must return boolean or DispatchResult'))
    end
    validate_result_field(value.handled, 'handled')
    validate_result_field(value.capture, 'capture')
    validate_result_field(value.stop_propagation, 'stop_propagation')
    return {
        handled = value.handled == true,
        capture = value.capture == true,
        stop_propagation = value.stop_propagation == true,
    }
end

---@param target DispatchResult
---@param result DispatchResult
local function merge_dispatch_result(target, result)
    target.handled = target.handled or result.handled
    target.capture = target.capture or result.capture
    target.stop_propagation = target.stop_propagation or result.stop_propagation
end

---@param event PointerEvent
---@return PointerButton?
local function pointer_button(event)
    if event.button ~= nil then
        return event.button
    end
    if type(event.data) == 'string' and POINTER_BUTTONS[event.data] then
        return event.data --[[@as PointerButton]]
    end
    return nil
end

---@param path {node: RenderObject, point: Offset}[]
---@param target RenderObject
---@return Offset?
local function local_point_for(path, target)
    for _, entry in ipairs(path) do
        if entry.node == target then
            return entry.point
        end
    end
    return nil
end

---@class RenderOwner : std.object
---@field root RenderObject?
---@field viewport Constraints
---@field on_dirty fun()?
---@field private _input_generation integer
---@field private _region_snapshot RegionSnapshot?
---@field private _cancelled_buttons table<PointerButton, true>
---@overload fun(root: RenderObject?): self
local RenderOwner = std.class.new('RenderOwner', {})

function RenderOwner:__init(root)
    self.root = nil
    -- A host that never calls `set_viewport` gets an unbounded box (Flutter's
    -- default `BoxConstraints()`), not a tightly infinite one.
    self.viewport = Constraints.unbounded()
    self.on_dirty = nil
    self._input_generation = 0
    self._region_snapshot = nil
    self._needs_layout = false
    self._needs_paint = false
    ---@type table<RenderObject, true>
    self._hovered = {}
    ---@type RenderObject?
    ---@type RenderObject?
    self._capture = nil
    ---@type table<PointerButton, true>
    self._capture_buttons = {}
    self._cancelled_sequence = false
    self._cancelled_buttons = {}
    if root then
        self:set_root(root)
    end
end

---@param root RenderObject?
---@param notify boolean? whether the replacement should schedule layout
function RenderOwner:set_root(root, notify)
    -- Root replacement invalidates both sides of pointer state. Send leave and
    -- cancel while the old tree still has its owner, then detach it.
    self:clear_hover()
    if self.root then
        self.root:_set_owner(nil)
    end
    self.root = root
    if root then
        root:_set_owner(self)
    end
    self:mark_needs_input()
    if notify == false then
        self._needs_layout = false
        self._needs_paint = false
    else
        self:mark_needs_layout()
    end
end

---@param constraints Constraints
function RenderOwner:set_viewport(constraints)
    self.viewport = constraints
    self:mark_needs_layout()
end

function RenderOwner:mark_needs_layout()
    self:mark_needs_input()
    self._needs_layout = true
    self._needs_paint = true
    if self.on_dirty then
        self.on_dirty()
    end
end

--- Input geometry/policy invalidation does not synthesize pointer movement.
function RenderOwner:mark_needs_input()
    self._input_generation = self._input_generation + 1
    self._region_snapshot = nil
end

function RenderOwner:mark_needs_paint()
    self._needs_paint = true
    if self.on_dirty then
        self.on_dirty()
    end
end

---@return boolean
function RenderOwner:needs_layout()
    return self._needs_layout
end

---@return boolean
function RenderOwner:needs_paint()
    return self._needs_paint
end

--- Lay the tree out when the viewport changed or anything was marked dirty.
function RenderOwner:layout()
    self:_cleanup_detached_pointer_state()
    local root = self.root
    if root == nil then
        self._needs_layout = false
        return
    end
    if not self._needs_layout and root.constraints == self.viewport then
        return
    end
    self._needs_layout = false
    self._needs_paint = true
    root:layout(self.viewport)
    self:mark_needs_input()
end

---@param canvas Canvas
function RenderOwner:paint(canvas)
    if self.root and self._needs_paint then
        self.root:paint(PaintingContext(canvas), Offset.zero())
    end
    self._needs_paint = false
end

--- Flutter-aligned pipeline names on the existing single-root owner.
function RenderOwner:flush_layout()
    self:layout()
end

---@param canvas Canvas
function RenderOwner:flush_paint(canvas)
    self:paint(canvas)
end

function RenderOwner:request_visual_update()
    self:mark_needs_paint()
end

function RenderOwner:dispose()
    self:set_root(nil, false)
    self.on_dirty = nil
    self._hovered = {}
    self._capture = nil
    self._capture_buttons = {}
end

--== pointer routing ======================================================

---@param point Offset
---@return {node: RenderObject, point: Offset}[]
function RenderOwner:pointer_path(point)
    if not self.root then
        return {}
    end
    return self.root:pointer_path(point)
end

---@return PointerRegion[]
function RenderOwner:pointer_regions()
    return self:region_snapshot():regions()
end

---@return RegionSnapshot
function RenderOwner:region_snapshot()
    if not self._region_snapshot then
        self._region_snapshot = RegionSnapshot({
            generation = self._input_generation,
            root = self.root,
            regions = self.root and self.root:collect_pointer_regions() or {},
        })
    end
    return self._region_snapshot
end

--- Return whether a pointer sequence is captured by a mounted node. If a
--- subtree rebuild detached the target, cancel that sequence before returning.
---@return boolean
function RenderOwner:has_pointer_capture()
    local capture = self._capture
    if capture and (capture.owner ~= self or self.root == nil) then
        self:cancel_pointer()
    end
    capture = self._capture
    return capture ~= nil
end

---@param event PointerEvents
---@param point Offset
---@return boolean
function RenderOwner:wants_pointer(event, point)
    for _, entry in ipairs(self:pointer_path(point)) do
        if entry.node:wants_pointer(event) then
            return true
        end
    end
    return false
end

--- Route a structured pointer event down the tree. `move` bubbles and drives
--- hover tracking (`enter`/`leave`); other events honor structured propagation
--- results while retaining the legacy boolean behavior.
---@param event PointerEvent|string
---@param point Offset?
---@param data any?
---@return DispatchResult
---@overload fun(event: PointerEvent): DispatchResult
function RenderOwner:dispatch_pointer_result(event, point, data)
    local pointer
    if type(event) == 'table' then
        if pointer_event.is_instance(event) then
            pointer = event --[[@as PointerEvent]]
        else
            pointer = PointerEvent(event --[[@as _PointerEventFields]])
        end
    else
        pointer = PointerEvent(event, point, data)
    end

    self:_cleanup_detached_pointer_state()
    local button = pointer_button(pointer)
    if pointer.type == 'down' then
        self._cancelled_sequence = false
        if button then
            self._cancelled_buttons[button] = nil
        end
    end
    if pointer.type == 'up' and (self._cancelled_sequence
        or (button and self._cancelled_buttons[button])) then
        self._cancelled_sequence = false
        if button then
            self._cancelled_buttons[button] = nil
        end
        return { handled = true, capture = self:has_pointer_capture(), stop_propagation = true }
    end

    local path = pointer.point and self:pointer_path(pointer.point) or {}
    if pointer.type == 'move' then
        local root_point = pointer.point --[[@as Offset]]
        self:_update_hover(path, root_point)
        self:has_pointer_capture()
        if self._capture then
            local captured = self._capture
            local result = normalize_dispatch_result(
                captured:on_pointer_event(pointer, local_point_for(path, captured)), pointer)
            result.handled = true
            result.capture = true
            result.stop_propagation = true
            return result
        end
        local result = { handled = false, capture = false, stop_propagation = false }
        for _, entry in ipairs(path) do
            if entry.node.owner == self then
                local entry_result = normalize_dispatch_result(
                    entry.node:on_pointer_event(pointer, entry.point), pointer)
                merge_dispatch_result(result, entry_result)
                if entry_result.stop_propagation then
                    break
                end
            end
        end
        return result
    end

    if pointer.type == 'down' then
        button = pointer_button(pointer)
        if self._capture and button ~= nil and not self._capture_buttons[button] then
            local captured = self._capture
            self._capture_buttons[button] = true
            local result = normalize_dispatch_result(
                captured:on_pointer_event(pointer, local_point_for(path, captured)), pointer)
            result.handled = true
            result.capture = true
            result.stop_propagation = true
            return result
        end
        if self._capture then
            self:cancel_pointer()
            -- A new down for the same button supersedes the cancelled
            -- sequence; its later up belongs to the new target.
            if button then
                self._cancelled_buttons[button] = nil
            end
        end
        self._cancelled_sequence = false
    elseif pointer.type == 'up' or pointer.type == 'cancel' then
        local captured = self._capture
        if captured then
            local result = normalize_dispatch_result(
                captured:on_pointer_event(pointer, local_point_for(path, captured)), pointer)
            if pointer.type == 'cancel' then
                self._capture = nil
                self._capture_buttons = {}
            else
                button = pointer_button(pointer)
                if button == nil then
                    self._capture_buttons = {}
                else
                    self._capture_buttons[button] = nil
                end
                if next(self._capture_buttons) == nil then
                    self._capture = nil
                end
            end
            result.handled = true
            result.capture = self._capture ~= nil
            result.stop_propagation = true
            return result
        end
    end

    local result = { handled = false, capture = false, stop_propagation = false }
    for _, entry in ipairs(path) do
        local entry_result = normalize_dispatch_result(
            entry.node:on_pointer_event(pointer, entry.point), pointer)
        merge_dispatch_result(result, entry_result)
        if pointer.type == 'down' and entry_result.capture
            and entry.node.owner == self and self._capture == nil then
            self._capture = entry.node
            self._capture_buttons = {}
            button = pointer_button(pointer)
            if button ~= nil then
                self._capture_buttons[button] = true
            end
        end
        if entry_result.stop_propagation then
            break
        end
    end
    return result
end

--- Compatibility wrapper retaining the historical boolean return value.
---@param event PointerEvent|string
---@param point Offset?
---@param data any?
---@return boolean handled
---@overload fun(event: PointerEvent): boolean
function RenderOwner:dispatch_pointer(event, point, data)
    local event_type
    local event_point
    if type(event) == 'table' then
        event_type = event.type
        event_point = event.point
    else
        event_type = event
        event_point = point
    end
    local result = self:dispatch_pointer_result(event, point, data)
    if event_type == 'move' and not result.handled and event_point ~= nil then
        return #self:pointer_path(event_point) > 0
    end
    return result.handled
end

--- Cancel a pending press when the host loses the pointer or the root changes.
function RenderOwner:cancel_pointer()
    local captured = self._capture
    self._capture = nil
    if captured then
        self._cancelled_sequence = next(self._capture_buttons) == nil
        for button in pairs(self._capture_buttons) do
            self._cancelled_buttons[button] = true
        end
        self._capture_buttons = {}
        captured:on_pointer_event(PointerEvent('cancel'), nil)
    end
    self._capture_buttons = {}
end

--- Mark every currently hovered node as left (pointer left the window).
function RenderOwner:clear_hover()
    self:cancel_pointer()
    for node in pairs(self._hovered) do
        node:on_pointer_event(PointerEvent('leave'), nil)
    end
    self._hovered = {}
end

---@return boolean detached_capture
function RenderOwner:_cleanup_detached_pointer_state()
    local detached_capture = false
    local capture = self._capture
    if capture and (capture.owner ~= self or self.root == nil) then
        detached_capture = true
        self:cancel_pointer()
    end
    for node in pairs(self._hovered) do
        if node.owner ~= self then
            self._hovered[node] = nil
        end
    end
    return detached_capture
end

---@param path {node: RenderObject, point: Offset}[]
---@param root_point Offset
function RenderOwner:_update_hover(path, root_point)
    local current = {}
    for _, entry in ipairs(path) do
        current[entry.node] = true
    end
    for node in pairs(self._hovered) do
        if not current[node] then
            node:on_pointer_event(PointerEvent('leave', root_point), nil)
        end
    end
    for _, entry in ipairs(path) do
        if not self._hovered[entry.node] then
            entry.node:on_pointer_event(PointerEvent('enter', root_point), entry.point)
        end
    end
    self._hovered = current
end

M.RenderOwner = RenderOwner

return M
