-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Boxes that impose *additional* constraints on their child.
--
--   * `RenderConstrainedBox` (Flutter's `ConstrainedBox`, and the render
--     object behind `SizedBox`): the additional constraints are intersected
--     with the incoming ones through `enforce`.
--   * `RenderLimitedBox` (Flutter's `LimitedBox`): the limit is only applied
--     on an axis whose incoming constraint is unbounded.

local std = require 'elxlibs.std'
local geometry = require 'foundation.geometry'
local constraints_mod = require 'layout.constraints'
local render_object = require 'render.render_object'

local Offset = geometry.Offset
local Size = geometry.Size
local Constraints = constraints_mod.Constraints
local RenderObject = render_object.RenderObject

---@class elxconstrainedbox
local M = {}

---@class RenderConstrainedBox : RenderObject
---@field additional Constraints
---@overload fun(additional: Constraints, child: RenderObject?): RenderConstrainedBox
local RenderConstrainedBox = std.class.new('RenderConstrainedBox', { RenderObject })

function RenderConstrainedBox:__init(additional, child)
    std.super(RenderConstrainedBox, self, RenderObject).__init(self)
    self.additional = additional
    if child then
        self:adopt_child(child)
    end
end

function RenderConstrainedBox:__perform_layout(constraints)
    local inner = self.additional:enforce(constraints)
    local child = self._children[1]
    if child then
        child:layout(inner)
        child.parent_data.offset = Offset.zero()
        self.size = child.size
    else
        self.size = inner:constrain_size(Size(0, 0))
    end
end

---@class RenderLimitedBox : RenderObject
---@field max_width number
---@field max_height number
---@overload fun(max_width: number?, max_height: number?, child: RenderObject?): RenderLimitedBox
local RenderLimitedBox = std.class.new('RenderLimitedBox', { RenderObject })

function RenderLimitedBox:__init(max_width, max_height, child)
    std.super(RenderLimitedBox, self, RenderObject).__init(self)
    self.max_width = max_width or math.huge
    self.max_height = max_height or math.huge
    if child then
        self:adopt_child(child)
    end
end

--- Only cap an axis whose incoming maximum is unbounded.
---@param constraints Constraints
---@return Constraints
function RenderLimitedBox:limit_constraints(constraints)
    local max_width = constraints:has_bounded_width()
        and constraints.max_width or constraints:constrain_width(self.max_width)
    local max_height = constraints:has_bounded_height()
        and constraints.max_height or constraints:constrain_height(self.max_height)
    return Constraints(
        constraints.min_width, max_width, constraints.min_height, max_height)
end

function RenderLimitedBox:__perform_layout(constraints)
    local inner = self:limit_constraints(constraints)
    local child = self._children[1]
    if child then
        child:layout(inner)
        child.parent_data.offset = Offset.zero()
        self.size = constraints:constrain_size(child.size)
    else
        self.size = inner:constrain_size(Size(0, 0))
    end
end

M.RenderConstrainedBox = RenderConstrainedBox
M.RenderLimitedBox = RenderLimitedBox

return M
