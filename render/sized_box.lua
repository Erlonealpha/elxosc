-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Single-child box that overrides its constraints (Flutter's
-- `RenderConstrainedBox` as used by `SizedBox`).

local std = require 'elxlibs.std'
local geometry = require 'foundation.geometry'
local constraints_mod = require 'layout.constraints'
local render_object = require 'render.render_object'

local Offset = geometry.Offset
local Size = geometry.Size
local Constraints = constraints_mod.Constraints
local RenderObject = render_object.RenderObject

---@class elxsizedbox
local M = {}

---@class RenderSizedBox : RenderObject
---@field width number?
---@field height number?
---@overload fun(width: number?, height: number?, child: RenderObject?): RenderSizedBox
local RenderSizedBox = std.class.new('RenderSizedBox', { RenderObject })

function RenderSizedBox:__init(width, height, child)
    std.super(RenderSizedBox, self, RenderObject).__init(self)
    self.width = width
    self.height = height
    if child then
        self:adopt_child(child)
    end
end

function RenderSizedBox:__perform_layout(constraints)
    local child = self._children[1]
    local inner = constraints
    if self.width then
        inner = Constraints(self.width, self.width, inner.min_height, inner.max_height)
    end
    if self.height then
        inner = Constraints(inner.min_width, inner.max_width, self.height, self.height)
    end

    if child then
        child:layout(inner)
        child.parent_data.offset = Offset.zero()
        self.size = Size(
            self.width or child.size.width,
            self.height or child.size.height)
    else
        local width = self.width or (constraints:has_bounded_width() and constraints.max_width or 0)
        local height = self.height or (constraints:has_bounded_height() and constraints.max_height or 0)
        self.size = Size(width, height)
    end
end

M.RenderSizedBox = RenderSizedBox

return M
