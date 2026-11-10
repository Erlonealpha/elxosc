-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Multi-child box that overlays its children in paint order (Flutter's
-- `RenderStack`). Children are aligned by a single shared fraction.
--
-- The default alignment is the top-left corner, matching `Stack`'s
-- `AlignmentDirectional.topStart`, not the centre.

local std = require 'elxlibs.std'
local geometry = require 'foundation.geometry'
local constraints_mod = require 'layout.constraints'
local render_object = require 'render.render_object'

local Offset = geometry.Offset
local Size = geometry.Size
local Constraints = constraints_mod.Constraints
local RenderObject = render_object.RenderObject
local math = math
local max = math.max
local ipairs = ipairs
local huge = math.huge

---@class elxosc.render.stack
local M = {}

---@class StackOpts
---@field children RenderObject[]?
---@field alignment Offset?

---@class RenderStack : RenderObject
---@field alignment Offset
---@overload fun(options: StackOpts?): self
local RenderStack = std.class.new('RenderStack', RenderObject)

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
    local non_positioned = 0
    for _, child in ipairs(children) do
        local data = child.parent_data or {}
        if data.positioned ~= true then
            non_positioned = non_positioned + 1
            child:layout(constraints:loosen())
            width = max(width, child.size.width)
            height = max(height, child.size.height)
        end
    end
    if non_positioned == 0 then
        local biggest = constraints:biggest()
        if biggest.width < huge and biggest.height < huge then
            width, height = biggest.width, biggest.height
        end
    end
    self.size = constraints:constrain_size(Size(width, height))
    for _, child in ipairs(children) do
        local data = child.parent_data or {}
        if data.positioned == true then
            local left, right = data.left, data.right
            local top, bottom = data.top, data.bottom
            local child_constraints = Constraints(
                0, self.size.width, 0, self.size.height)
            local width_value = data.width
            local height_value = data.height
            if width_value == nil and left ~= nil and right ~= nil then
                width_value = max(0, self.size.width - left - right)
            end
            if height_value == nil and top ~= nil and bottom ~= nil then
                height_value = max(0, self.size.height - top - bottom)
            end
            if width_value ~= nil then
                child_constraints = child_constraints:tighten({ width = width_value })
            elseif left ~= nil or right ~= nil then
                local max_width = self.size.width
                if left ~= nil then
                    max_width = max(0, max_width - left)
                end
                if right ~= nil then
                    max_width = max(0, max_width - right)
                end
                child_constraints = Constraints(0, max_width,
                    child_constraints.min_height, child_constraints.max_height)
            end
            if height_value ~= nil then
                child_constraints = child_constraints:tighten({ height = height_value })
            elseif top ~= nil or bottom ~= nil then
                local max_height = self.size.height
                if top ~= nil then
                    max_height = max(0, max_height - top)
                end
                if bottom ~= nil then
                    max_height = max(0, max_height - bottom)
                end
                child_constraints = Constraints(child_constraints.min_width,
                    child_constraints.max_width, 0, max_height)
            end
            child:layout(child_constraints)
            local x = left
            if x == nil and right ~= nil then
                x = self.size.width - right - child.size.width
            end
            if x == nil then
                x = (self.size.width - child.size.width) * self.alignment.x
            end
            local y = top
            if y == nil and bottom ~= nil then
                y = self.size.height - bottom - child.size.height
            end
            if y == nil then
                y = (self.size.height - child.size.height) * self.alignment.y
            end
            child.parent_data.offset = Offset(x, y)
        else
            child.parent_data.offset = Offset(
                (self.size.width - child.size.width) * self.alignment.x,
                (self.size.height - child.size.height) * self.alignment.y)
        end
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

-- A hover-only layer (for example a tooltip) may sit above a clickable child.
-- Keep it in the move path, but continue looking for the first child that can
-- receive a down/up/wheel event so hover overlays do not swallow clicks.
local function path_has_action_target(path)
    for _, entry in ipairs(path) do
        local node = entry.node
        if node:wants_pointer('down') or node:wants_pointer('up')
            or node:wants_pointer('wheel') then
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
                if path_has_action_target(child_path) then
                    break
                end
            end
        end
    end

    out[#out + 1] = { node = self, point = point }
    return out
end

M.RenderStack = RenderStack

return M
