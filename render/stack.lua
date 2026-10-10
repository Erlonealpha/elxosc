-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Multi-child box that overlays its children in paint order (Flutter's
-- `RenderStack`). Children are aligned by a single shared fraction.
--
-- The default alignment is the top-left corner, matching `Stack`'s
-- `AlignmentDirectional.topStart`, not the centre.

local std = require 'elxlibs.std'
local geometry = require 'foundation.geometry'
local render_object = require 'render.render_object'

local Offset = geometry.Offset
local Size = geometry.Size
local RenderObject = render_object.RenderObject
local math = math
local max = math.max
local ipairs = ipairs

local M = {}

---@class StackOpts
---@field children RenderObject[]?
---@field alignment Offset?

---@class RenderStack : RenderObject
---@field alignment Offset
---@overload fun(options: StackOpts?): RenderStack
local RenderStack = std.class.new('RenderStack', { RenderObject })

function RenderStack:__init(options)
    RenderObject.__init(self)
    options = options or {}
    self.alignment = options.alignment or Offset(0, 0)
    for _, child in ipairs(options.children or {}) do
        self:adopt_child(child)
    end
end

function RenderStack:__perform_layout(constraints)
    local children = self._children
    local width, height = 0, 0
    for _, child in ipairs(children) do
        child:layout(constraints:loosen())
        width = max(width, child.size.width)
        height = max(height, child.size.height)
    end
    self.size = constraints:constrain_size(Size(width, height))
    for _, child in ipairs(children) do
        child.parent_data.offset = Offset(
            (self.size.width - child.size.width) * self.alignment.x,
            (self.size.height - child.size.height) * self.alignment.y)
    end
end

M.RenderStack = RenderStack

return M
