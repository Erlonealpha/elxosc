-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Single-child box that positions its child by an alignment fraction
-- (Flutter's `RenderPositionedBox`: `Center`, `Align`).

local std = require 'elxlibs.std'
local geometry = require 'foundation.geometry'
local render_object = require 'render.render_object'

local Offset = geometry.Offset
local Size = geometry.Size
local RenderObject = render_object.RenderObject

---@class elxalign
local M = {}

---@class RenderAlign : RenderObject
---@field alignment Offset (0,0)=top-left, (0.5,0.5)=center, (1,1)=bottom-right
---@field width_factor number?
---@field height_factor number?
---@overload fun(alignment: Offset?, child: RenderObject?, width_factor: number?, height_factor: number?): RenderAlign
local RenderAlign = std.class.new('RenderAlign', { RenderObject })

function RenderAlign:__init(alignment, child, width_factor, height_factor)
    RenderObject.__init(self)
    self.alignment = alignment or Offset(0.5, 0.5)
    self.width_factor = width_factor
    self.height_factor = height_factor
    if child then
        self:adopt_child(child)
    end
end

function RenderAlign:__perform_layout(constraints)
    local child = self._children[1]
    if child == nil then
        return
    end
    child:layout(constraints:loosen())
    local width = self.width_factor and (child.size.width * self.width_factor)
        or (constraints:has_bounded_width() and constraints.max_width or child.size.width)
    local height = self.height_factor and (child.size.height * self.height_factor)
        or (constraints:has_bounded_height() and constraints.max_height or child.size.height)
    self.size = constraints:constrain_size(Size(width, height))
    child.parent_data.offset = Offset(
        (self.size.width - child.size.width) * self.alignment.x,
        (self.size.height - child.size.height) * self.alignment.y)
end

M.RenderAlign = RenderAlign

return M
