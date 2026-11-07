-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Paint-only subtree opacity. It keeps layout, hit testing and pointer regions
-- unchanged; input policy belongs to a separate visibility or host decision.

local std = require 'elxlibs.std'
local geometry = require 'foundation.geometry'
local transform_mod = require 'foundation.transform'
local render_object = require 'render.render_object'

local Offset = geometry.Offset
local Size = geometry.Size
local Matrix2D = transform_mod.Matrix2D
local RenderObject = render_object.RenderObject
local raise = std.raise
local huge = math.huge

local M = {}

---@param value number
---@return number
local function validate_opacity(value)
    if type(value) ~= 'number' or value ~= value
        or value == huge or value == -huge
        or value < 0 or value > 1 then
        raise(std.ValueError('RenderOpacity.opacity must be between 0 and 1'))
    end
    return value
end

---@class RenderOpacity : RenderObject
---@field opacity number
---@field hidden boolean suppress paint, hit testing and pointer regions while retaining layout
---@overload fun(opacity: number?, child: RenderObject?, hidden: boolean?): self
local RenderOpacity = std.class.new('RenderOpacity', RenderObject)

---@param opacity number?
---@param child RenderObject?
---@param hidden boolean?
function RenderOpacity:__init(opacity, child, hidden)
    RenderObject.__init(self)
    local initial_opacity = opacity
    if initial_opacity == nil then
        initial_opacity = 1
    end
    self.opacity = validate_opacity(initial_opacity)
    if hidden ~= nil and type(hidden) ~= 'boolean' then
        raise(std.TypeError('RenderOpacity.hidden must be a boolean'))
    end
    self.hidden = hidden == true
    if child then
        self:adopt_child(child)
    end
end

---@param opacity number
function RenderOpacity:set_opacity(opacity)
    opacity = validate_opacity(opacity)
    if self.opacity == opacity then
        return
    end
    self.opacity = opacity
    self:mark_needs_paint()
end

---@param hidden boolean
function RenderOpacity:set_hidden(hidden)
    if type(hidden) ~= 'boolean' then
        raise(std.TypeError('RenderOpacity.hidden must be a boolean'))
    end
    if self.hidden == hidden then
        return
    end
    self.hidden = hidden
    self:mark_needs_paint()
    self:mark_needs_input()
end

---@param constraints Constraints
function RenderOpacity:__perform_layout(constraints)
    local child = self._children[1]
    if child then
        child:layout(constraints)
        child.parent_data.offset = Offset.zero()
        self.size = child.size
    else
        self.size = constraints:constrain_size(Size.zero())
    end
end

---@param canvas PaintingContext
---@param offset Offset
function RenderOpacity:__paint(canvas, offset)
    if self.hidden then
        return
    end
    local child = self._children[1]
    if child == nil then
        return
    end
    canvas:with_opacity(self.opacity, function()
        canvas:paint_child(child, offset)
    end)
end

function RenderOpacity:hit_test(position)
    if self.hidden then
        return nil
    end
    return RenderObject.hit_test(self, position)
end

---@param point Offset
---@param out {node: RenderObject, point: Offset}[]?
---@return {node: RenderObject, point: Offset}[]
function RenderOpacity:pointer_path(point, out)
    out = out or {}
    if self.hidden then
        return out
    end
    return RenderObject.pointer_path(self, point, out)
end

---@param out PointerRegion[]?
---@param local_to_root Matrix2D?
---@return PointerRegion[]
function RenderOpacity:collect_pointer_regions(out, local_to_root)
    out = out or {}
    if self.hidden then
        return out
    end
    return RenderObject.collect_pointer_regions(self, out, local_to_root)
end

M.RenderOpacity = RenderOpacity

return M
