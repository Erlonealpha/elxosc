-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Render tree node (Flutter's `RenderObject` + `RenderBox`, merged).
--
-- Layout follows Flutter's protocol exactly: the parent passes `Constraints`
-- down, the child computes a `Size` up, and the parent decides where the child
-- sits (via `child.parent_data.offset`). Nodes are mutable and survive between
-- frames; they recompute only when marked dirty.

local std = require 'elxlibs.std'
local geometry = require 'foundation.geometry'
local transform_mod = require 'foundation.transform'
local pointer_event = require 'foundation.pointer_event'

local Offset = geometry.Offset
local Rect = geometry.Rect
local Size = geometry.Size
local Matrix2D = transform_mod.Matrix2D
local legacy_pointer_data = pointer_event.legacy_data
local table = table
local ipairs = ipairs
local huge = math.huge
local raise = std.raise

local M = {}

---@alias FlexFit
--- | 'tight'
--- | 'loose'

--- Per-child layout data written by the parent (Flutter's `BoxParentData`).
---@class BoxParentData
---@field offset Offset
---@field flex number? main-axis flex weight (see RenderFlex)
---@field fit FlexFit? flex fit (see RenderFlex)

---@class PointerRegion
---@field node RenderObject
---@field rect Rect root-space input bounds
---@field down boolean
---@field wheel boolean

---@class DispatchResult
---@field handled boolean whether a node handled the event
---@field capture boolean whether a down event requests pointer capture
---@field stop_propagation boolean whether ancestor dispatch should stop

---@class RenderObject : std.object
---@field parent RenderObject?
---@field owner RenderOwner?
---@field parent_data BoxParentData
---@field size Size
---@field constraints Constraints?
---@field needs_layout boolean
---@field needs_paint boolean
---@field _children RenderObject[]
---@overload fun(): self
local RenderObject = std.class.new('RenderObject', {})

function RenderObject:__init()
    self.parent = nil
    self.owner = nil
    self.parent_data = { offset = Offset.zero() }
    self.size = Size(0, 0)
    self.constraints = nil
    self.needs_layout = true
    self.needs_paint = true
    self._children = {}
end

---@return RenderObject[]
function RenderObject:children()
    return self._children
end

---@param child RenderObject
---@return self
function RenderObject:adopt_child(child)
    child.parent = self
    if child.parent_data == nil then
        child.parent_data = { offset = Offset.zero() }
    end
    self._children[#self._children + 1] = child
    child:_set_owner(self.owner)
    self:mark_needs_layout()
    return self
end

---@param child RenderObject
function RenderObject:remove_child(child)
    for i, candidate in ipairs(self._children) do
        if candidate == child then
            table.remove(self._children, i)
            child.parent = nil
            child:_set_owner(nil)
            self:mark_needs_layout()
            return
        end
    end
end

--- Replace the whole child list, keeping the given order and detaching the
--- children that were dropped. A no-op (and no relayout) when the list is
--- already identical, which is what makes repeated builds cheap.
---@param list RenderObject[]
function RenderObject:set_children(list)
    local current = self._children
    if #current == #list then
        local same = true
        for i = 1, #list do
            if current[i] ~= list[i] then
                same = false
                break
            end
        end
        if same then
            return
        end
    end
    for _, child in ipairs(current) do
        local kept = false
        for i = 1, #list do
            if list[i] == child then
                kept = true
                break
            end
        end
        if not kept then
            child.parent = nil
            child:_set_owner(nil)
        end
    end
    local next_children = {}
    for i, child in ipairs(list) do
        child.parent = self
        child:_set_owner(self.owner)
        next_children[i] = child
    end
    self._children = next_children
    self:mark_needs_layout()
end

---@param owner RenderOwner?
function RenderObject:_set_owner(owner)
    self.owner = owner
    for _, child in ipairs(self._children) do
        child:_set_owner(owner)
    end
end

--== layout ===============================================================

--- Lay this node (and its subtree) out under `constraints`. A node whose
--- constraints are unchanged and that is not dirty is left untouched.
---@param constraints Constraints
function RenderObject:layout(constraints)
    if not self.needs_layout and self.constraints == constraints then
        return
    end
    self.constraints = constraints
    self.needs_layout = false
    self.needs_paint = true
    self:__perform_layout(constraints)
    local size = constraints:constrain_size(self.size)
    -- Flutter cannot render infinite geometry; the doc's Example 16 (an
    -- unbounded `Container(width: infinity)`) and Example 22 (`FittedBox` of an
    -- infinite child) both surface this as an error.
    if size.width == huge or size.width ~= size.width then
        raise(std.RuntimeError('BoxConstraints forces an infinite width'))
    end
    if size.height == huge or size.height ~= size.height then
        raise(std.RuntimeError('BoxConstraints forces an infinite height'))
    end
    self.size = size
end

--- Subclasses set `self.size` here (and lay out their children).
---@param constraints Constraints
function RenderObject:__perform_layout(constraints)
    self.size = constraints:constrain_size(self.size)
end

--== painting =============================================================

---@param canvas Canvas
---@param offset Offset top-left of this node in canvas space
function RenderObject:paint(canvas, offset)
    self:__paint(canvas, offset)
    self.needs_paint = false
end

--- Default paints nothing but the children. Subclasses draw their own content
--- first, then call `self:paint_children(canvas, offset)`.
---@param canvas Canvas
---@param offset Offset
function RenderObject:__paint(canvas, offset)
    self:paint_children(canvas, offset)
end

---@param canvas Canvas
---@param offset Offset
function RenderObject:paint_children(canvas, offset)
    for _, child in ipairs(self._children) do
        local child_offset = offset
        if child.parent_data and child.parent_data.offset then
            child_offset = (offset + child.parent_data.offset) --[[@as Offset]]
        end
        child:paint(canvas, child_offset)
    end
end

--== hit testing ==========================================================

---@param position Offset #in this node's coordinate space
---@return RenderObject? the deepest node under the point, or nil
function RenderObject:hit_test(position)
    if not self:__hit_test_bounds(position) then
        return nil
    end
    for i = #self._children, 1, -1 do
        local child = self._children[i]
        local local_pos = position
        if child.parent_data and child.parent_data.offset then
            local_pos = (position - child.parent_data.offset) --[[@as Offset]]
        end
        local hit = child:hit_test(local_pos)
        if hit then
            return hit
        end
    end
    return self
end

---@param position Offset
---@return boolean
function RenderObject:__hit_test_bounds(position)
    return position.x >= 0 and position.y >= 0
        and position.x < self.size.width and position.y < self.size.height
end

---@param path {node: RenderObject, point: Offset}[]
---@param event_type PointerEventType?
---@return boolean
local function path_has_pointer_target(path, event_type)
    for _, entry in ipairs(path) do
        local node = entry.node
        if event_type == nil then
            if node:wants_pointer('down') or node:wants_pointer('up')
                or node:wants_pointer('wheel') or node:wants_pointer('move') then
                return true
            end
        elseif node:wants_pointer(event_type) then
            return true
        end
    end
    return false
end

---@param point Offset
---@param out {node: RenderObject, point: Offset}[]?
---@param event_type PointerEventType?
---@return {node: RenderObject, point: Offset}[]
function RenderObject:pointer_path(point, out, event_type)
    out = out or {}
    if not self:__hit_test_bounds(point) then
        return out
    end
    ---@type {node: RenderObject, point: Offset}[]?
    local fallback_path = nil
    -- A passive layout child may fill the viewport while its actual child is
    -- elsewhere. Keep searching lower Stack siblings when that branch has no
    -- target for this event; otherwise a full-size Align would hide buttons
    -- painted below it from the render-tree hit test.
    for i = #self._children, 1, -1 do
        local child = self._children[i]
        local local_point = point
        if child.parent_data and child.parent_data.offset then
            local_point = (point - child.parent_data.offset) --[[@as Offset]]
        end
        if child:__hit_test_bounds(local_point) then
            local candidate = child:pointer_path(local_point, nil, event_type)
            if path_has_pointer_target(candidate, event_type) then
                for _, entry in ipairs(candidate) do
                    out[#out + 1] = entry
                end
                fallback_path = nil
                break
            end
            if fallback_path == nil then
                fallback_path = candidate
            end
        end
    end
    if fallback_path ~= nil then
        for _, entry in ipairs(fallback_path) do
            out[#out + 1] = entry
        end
    end
    out[#out + 1] = { node = self, point = point }
    return out
end

--- Collect interactive regions in root coordinates. Host input code can use the
--- result to constrain mpv sections without making the render layer depend on
--- mpv. Subclasses with paint/input transforms override this method to compose
--- their local-to-parent mapping.
---@param out PointerRegion[]?
---@param local_to_root Matrix2D?
---@return PointerRegion[]
function RenderObject:collect_pointer_regions(out, local_to_root)
    out = out or {}
    local_to_root = local_to_root or Matrix2D.identity()

    self:_append_pointer_region(out, local_to_root)

    local child_start = #out
    for _, child in ipairs(self._children) do
        local child_offset = child.parent_data and child.parent_data.offset or Offset.zero()
        child:collect_pointer_regions(out,
            local_to_root:multiply(Matrix2D.translation(child_offset.x, child_offset.y)))
    end
    self:_clip_pointer_regions(out, child_start, local_to_root)
    return out
end

---@param out PointerRegion[]
---@param local_to_root Matrix2D
function RenderObject:_append_pointer_region(out, local_to_root)
    local wants_down = self:wants_pointer('down') or self:wants_pointer('up')
    local wants_wheel = self:wants_pointer('wheel')
    if not wants_down and not wants_wheel then
        return
    end
    local rect = local_to_root:transform_rect(self:input_region_rect())
    if rect:is_empty() then
        return
    end
    out[#out + 1] = {
        node = self,
        rect = rect,
        down = wants_down,
        wheel = wants_wheel,
    }
end

---@param out PointerRegion[]
---@param start integer number of entries already present before this node's children
---@param local_to_root Matrix2D
function RenderObject:_clip_pointer_regions(out, start, local_to_root)
    local clip = local_to_root:transform_rect(self:input_region_rect())
    for index = #out, start + 1, -1 do
        local rect = out[index].rect:intersect(clip)
        if rect:is_empty() then
            table.remove(out, index)
        else
            out[index].rect = rect
        end
    end
end

---@return Rect
function RenderObject:input_region_rect()
    return Rect.from_offset_size(Offset.zero(), self.size)
end

--== pointer events =======================================================

--- Hook invoked by `RenderOwner:dispatch_pointer_result`. `point` is in this
--- node's local space; `event.point` remains in root space. Return a boolean
--- for the legacy contract or a DispatchResult to separate handling, capture,
--- and propagation. The default adapts to `on_pointer`.
---@param event PointerEvent
---@param point Offset?
---@return boolean|DispatchResult|nil
function RenderObject:on_pointer_event(event, point)
    local handled = self:on_pointer(event.type, point, legacy_pointer_data(event))
    return handled and true or false
end

--- Legacy pointer hook retained for existing RenderObject implementations.
---@param event PointerEvents
---@param point Offset?
---@param data any? wheel delta
---@return boolean handled
function RenderObject:on_pointer(event, point, data)
    return false
end

--- Whether this node cares about `event`; the host uses it to decide which
--- mpv key bindings to enable while the cursor is over this subtree.
---@param event PointerEvents
---@return boolean
function RenderObject:wants_pointer(event)
    return false
end

--== dirty tracking =======================================================

function RenderObject:mark_needs_layout()
    self.needs_layout = true
    self.needs_paint = true
    local parent = self.parent
    if parent then
        parent:mark_needs_layout()
    elseif self.owner then
        self.owner:mark_needs_layout()
    end
end

function RenderObject:mark_needs_paint()
    self.needs_paint = true
    local parent = self.parent
    if parent then
        parent:mark_needs_paint()
    elseif self.owner then
        self.owner:mark_needs_paint()
    end
end

M.RenderObject = RenderObject

return M
