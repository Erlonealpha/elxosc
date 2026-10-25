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
---@overload fun(options: StackOpts?): self
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

-- A passive full-size layer must not hide an interactive sibling below it.
-- The ordinary hit-test walk is intentionally topmost-child-first, but pointer
-- routing needs the topmost child that actually declares a pointer handler.
-- This keeps a full-screen Main/background layer from swallowing extension or
-- popup controls while preserving the normal paint order.
local function path_has_pointer_target(path)
    for _, entry in ipairs(path) do
        local node = entry.node
        if node:wants_pointer('down') or node:wants_pointer('up')
            or node:wants_pointer('move') or node:wants_pointer('wheel') then
            return true
        end
    end
    return false
end

---@param point Offset
---@param out {node: RenderObject, point: Offset}[]?
---@return {node: RenderObject, point: Offset}[]
function RenderStack:pointer_path(point, out)
    out = out or {}
    if not self:__hit_test_bounds(point) then
        return out
    end

    for index = #self._children, 1, -1 do
        local child = self._children[index]
        local child_point = point
        if child.parent_data and child.parent_data.offset then
            child_point = (point - child.parent_data.offset) --[[@as Offset]]
        end
        if child:__hit_test_bounds(child_point) then
            local child_path = {}
            child:pointer_path(child_point, child_path)
            if path_has_pointer_target(child_path) then
                for _, entry in ipairs(child_path) do
                    out[#out + 1] = entry
                end
                break
            end
        end
    end

    out[#out + 1] = { node = self, point = point }
    return out
end

M.RenderStack = RenderStack

return M
