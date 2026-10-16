-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- A single-child box that translates only painting and input coordinates.
--
-- The child is laid out with the incoming constraints and the box reports the
-- child's original size. The offset therefore cannot disturb Flex/Align or
-- any other parent's layout. Painting uses Canvas:translate; hit testing uses
-- the inverse offset and remains clipped to this box's logical bounds.

local std = require 'elxlibs.std'
local geometry = require 'foundation.geometry'
local transform_mod = require 'foundation.transform'
local render_object = require 'render.render_object'

local Offset = geometry.Offset
local Size = geometry.Size
local Matrix2D = transform_mod.Matrix2D
local RenderObject = render_object.RenderObject

local M = {}

---@class RenderOffsetBox : RenderObject
---@field offset Offset
---@field _offset_animation table?
---@overload fun(offset: Offset?, child: RenderObject?): self
local RenderOffsetBox = std.class.new('RenderOffsetBox', { RenderObject })

function RenderOffsetBox:__init(offset, child)
    RenderObject.__init(self)
    self.offset = offset or Offset.zero()
    self._offset_animation = nil
    if child then
        self:adopt_child(child)
    end
end

---@param offset Offset
function RenderOffsetBox:set_offset(offset)
    if self.offset == offset then
        return
    end
    self.offset = offset
    self:mark_needs_paint()
end

---@param child_offset Offset
---@return Offset
function RenderOffsetBox:_child_offset(child_offset)
    ---@type Offset
    local result = self.offset
    if child_offset then
        result = result + child_offset
    end
    return result --[[@as Offset]]
end

function RenderOffsetBox:__perform_layout(constraints)
    local child = self._children[1]
    if child == nil then
        self.size = constraints:constrain_size(Size.zero())
        return
    end
    child:layout(constraints)
    self.size = child.size
end

function RenderOffsetBox:__paint(canvas, offset)
    local child = self._children[1]
    if child == nil then
        return
    end
    local child_offset = self:_child_offset(child.parent_data and child.parent_data.offset)
    if child_offset.x == 0 and child_offset.y == 0 then
        child:paint(canvas, offset)
        return
    end
    canvas:save()
    canvas:translate(offset.x + child_offset.x, offset.y + child_offset.y)
    child:paint(canvas, Offset.zero())
    canvas:restore()
end

---@param position Offset
---@return RenderObject?
function RenderOffsetBox:hit_test(position)
    if not self:__hit_test_bounds(position) then
        return nil
    end
    local child = self._children[1]
    if child then
        local local_position = (position - self:_child_offset(child.parent_data and child.parent_data.offset)) --[[@as Offset]]
        local hit = child:hit_test(local_position)
        if hit then
            return hit
        end
    end
    return self
end

---@param point Offset
---@param out {node: RenderObject, point: Offset}[]?
---@param event_type PointerEventType?
---@return {node: RenderObject, point: Offset}[]
function RenderOffsetBox:pointer_path(point, out, event_type)
    out = out or {}
    if not self:__hit_test_bounds(point) then
        return out
    end
    local child = self._children[1]
    if child then
        local child_offset = self:_child_offset(child.parent_data and child.parent_data.offset)
        local local_point = (point - child_offset) --[[@as Offset]]
        if child:__hit_test_bounds(local_point) then
            child:pointer_path(local_point, out, event_type)
        end
    end
    out[#out + 1] = { node = self, point = point }
    return out
end

---@param out PointerRegion[]?
---@param local_to_root Matrix2D?
---@return PointerRegion[]
function RenderOffsetBox:collect_pointer_regions(out, local_to_root)
    out = out or {}
    local_to_root = local_to_root or Matrix2D.identity()
    self:_append_pointer_region(out, local_to_root)
    local child = self._children[1]
    if child then
        local child_offset = self:_child_offset(child.parent_data and child.parent_data.offset)
        local child_start = #out
        child:collect_pointer_regions(out,
            local_to_root:multiply(Matrix2D.translation(child_offset.x, child_offset.y)))
        self:_clip_pointer_regions(out, child_start, local_to_root)
    end
    return out
end

---@param controller AnimationController
---@param tween Tween<Offset>
---@return self
function RenderOffsetBox:bind_offset_animation(controller, tween)
    self:unbind_offset_animation()
    local listener = function()
        self:set_offset(tween:value_at(controller.value))
    end
    controller:add_listener(listener)
    self._offset_animation = {
        controller = controller,
        listener = listener,
    }
    listener()
    return self
end

function RenderOffsetBox:unbind_offset_animation()
    local binding = self._offset_animation
    if not binding then
        return
    end
    binding.controller:remove_listener(binding.listener)
    self._offset_animation = nil
end

---@param owner RenderOwner?
function RenderOffsetBox:_set_owner(owner)
    RenderObject._set_owner(self, owner)
    if owner == nil then
        self:unbind_offset_animation()
    end
end

M.RenderOffsetBox = RenderOffsetBox

return M
