-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Boxes that hand their child *different* constraints than they received.
--
--   * `RenderUnconstrainedBox` (Flutter's `UnconstrainedBox`): the child is
--     laid out completely unbounded, then we shrink to the child but never past
--     the incoming constraints.
--   * `RenderOverflowBox` (Flutter's `OverflowBox`): the caller overrides
--     individual min/max values; the box itself is as big as the parent allows.

local std = require 'elxlibs.std'
local geometry = require 'foundation.geometry'
local constraints_mod = require 'layout.constraints'
local render_object = require 'render.render_object'

local Offset = geometry.Offset
local Size = geometry.Size
local Constraints = constraints_mod.Constraints
local RenderObject = render_object.RenderObject

local M = {}

---@class RenderUnconstrainedBox : RenderObject
---@field alignment Offset
---@overload fun(child: RenderObject?, alignment: Offset?): self
local RenderUnconstrainedBox = std.class.new('RenderUnconstrainedBox', { RenderObject })

function RenderUnconstrainedBox:__init(child, alignment)
    RenderObject.__init(self)
    self.alignment = alignment or Offset(0.5, 0.5)
    if child then
        self:adopt_child(child)
    end
end

function RenderUnconstrainedBox:__perform_layout(constraints)
    local child = self._children[1]
    if child == nil then
        self.size = constraints:smallest()
        return
    end
    child:layout(Constraints.unbounded())
    self.size = constraints:constrain_size(child.size)
    child.parent_data.offset = Offset(
        (self.size.width - child.size.width) * self.alignment.x,
        (self.size.height - child.size.height) * self.alignment.y)
end

---@alias OverflowBoxFit
--- | 'max'
--- | 'defer_to_child'

---@class OverflowBoxOpts
---@field min_width number?
---@field max_width number?
---@field min_height number?
---@field max_height number?
---@field fit OverflowBoxFit?
---@field alignment Offset?

---@class RenderOverflowBox : RenderObject
---@field opts OverflowBoxOpts
---@overload fun(child: RenderObject?, options: OverflowBoxOpts?): self
local RenderOverflowBox = std.class.new('RenderOverflowBox', { RenderObject })

function RenderOverflowBox:__init(child, options)
    RenderObject.__init(self)
    options = options or {}
    self.opts = options
    self.alignment = options.alignment or Offset(0.5, 0.5)
    self.fit = options.fit or 'max'
    if child then
        self:adopt_child(child)
    end
end

---@param constraints Constraints
---@return Constraints
function RenderOverflowBox:inner_constraints(constraints)
    local opts = self.opts
    return Constraints(
        opts.min_width or constraints.min_width,
        opts.max_width or constraints.max_width,
        opts.min_height or constraints.min_height,
        opts.max_height or constraints.max_height)
end

function RenderOverflowBox:__perform_layout(constraints)
    local child = self._children[1]
    if self.fit == 'defer_to_child' then
        self.size = child and constraints:constrain_size(child.size) or constraints:smallest()
    else
        -- `OverflowBoxFit.max`: sized by the parent, ignoring the child.
        self.size = constraints:biggest()
    end
    if child == nil then
        return
    end
    child:layout(self:inner_constraints(constraints))
    child.parent_data.offset = Offset(
        (self.size.width - child.size.width) * self.alignment.x,
        (self.size.height - child.size.height) * self.alignment.y)
end

M.RenderUnconstrainedBox = RenderUnconstrainedBox
M.RenderOverflowBox = RenderOverflowBox

return M
