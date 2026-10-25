-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- A layout-preserving lifecycle boundary that paints and hit-tests nothing
-- while offstage.  It is the small primitive used by Visibility and Overlay
-- entries that keep State mounted while they are hidden or occluded.

local std = require 'elxlibs.std'
local geometry = require 'foundation.geometry'
local transform_mod = require 'foundation.transform'
local render_object = require 'render.render_object'

local Offset = geometry.Offset
local Size = geometry.Size
local Matrix2D = transform_mod.Matrix2D
local RenderObject = render_object.RenderObject

local M = {}

---@class RenderOffstage : RenderObject
---@field offstage boolean
---@overload fun(offstage: boolean?, child: RenderObject?): self
local RenderOffstage = std.class.new('RenderOffstage', { RenderObject })

function RenderOffstage:__init(offstage, child)
    std.super(RenderOffstage, self, RenderObject).__init(self)
    self.offstage = offstage == true
    if child then
        self:adopt_child(child)
    end
end

---@param offstage boolean
function RenderOffstage:set_offstage(offstage)
    if type(offstage) ~= 'boolean' then
        error('RenderOffstage.offstage must be a boolean', 2)
    end
    if self.offstage == offstage then
        return
    end
    self.offstage = offstage
    self:mark_needs_layout()
end

function RenderOffstage:__perform_layout(constraints)
    local child = self._children[1]
    if child then
        child:layout(constraints)
        child.parent_data.offset = Offset.zero()
        self.size = self.offstage and Size.zero() or child.size
    else
        self.size = constraints:constrain_size(Size.zero())
    end
end

function RenderOffstage:__paint(canvas, offset)
    if self.offstage then
        return
    end
    self:paint_children(canvas, offset)
end

function RenderOffstage:hit_test(position)
    if self.offstage then
        return nil
    end
    return RenderObject.hit_test(self, position)
end

---@param point Offset
---@param out {node: RenderObject, point: Offset}[]?
---@return {node: RenderObject, point: Offset}[]
function RenderOffstage:pointer_path(point, out)
    out = out or {}
    if self.offstage then
        return out
    end
    return RenderObject.pointer_path(self, point, out)
end

---@param out PointerRegion[]?
---@param local_to_root Matrix2D?
---@return PointerRegion[]
function RenderOffstage:collect_pointer_regions(out, local_to_root)
    out = out or {}
    if self.offstage then
        return out
    end
    return RenderObject.collect_pointer_regions(self, out, local_to_root)
end

M.RenderOffstage = RenderOffstage

return M
