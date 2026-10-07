-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Multi-child box that lays children out along one axis (Flutter's
-- `RenderFlex`: `Row`, `Column`).
--
-- A child carrying `parent_data.flex > 0` shares the leftover main-axis space
-- with the other flex children, exactly like `Expanded`/`Flexible`. Flex is
-- ignored on an unbounded main axis (where nothing is left to share).

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
local huge = math.huge
local ipairs = ipairs

---@class elxflex
local M = {}

---@class FlexOpts
---@field children RenderObject[]?
---@field main_alignment "start" | "center" | "end" | "space_between"?
---@field cross_alignment "start" | "center" | "end"?
---@field spacing number?

---@class RenderFlex : RenderObject
---@field direction "row" | "column"
---@field main_alignment string
---@field cross_alignment string
---@field spacing number
---@overload fun(direction: "row" | "column", options: FlexOpts?): RenderFlex
local RenderFlex = std.class.new('RenderFlex', { RenderObject })

function RenderFlex:__init(direction, options)
    RenderObject.__init(self)
    options = options or {}
    self.direction = direction or 'row'
    self.main_alignment = options.main_alignment or 'start'
    self.cross_alignment = options.cross_alignment or 'start'
    self.spacing = options.spacing or 0
    for _, child in ipairs(options.children or {}) do
        self:adopt_child(child)
    end
end

---@param horizontal boolean
---@return Constraints
local function axis(horizontal, main_min, main_max, cross_min, cross_max)
    if horizontal then
        return Constraints(main_min, main_max, cross_min, cross_max)
    end
    return Constraints(cross_min, cross_max, main_min, main_max)
end

---@param alignment string
---@return number 0..1
local function factor(alignment)
    if alignment == 'center' then
        return 0.5
    elseif alignment == 'end' then
        return 1
    end
    return 0
end

function RenderFlex:__perform_layout(constraints)
    local horizontal = self.direction == 'row'
    local children = self._children
    local n = #children
    if n == 0 then
        self.size = Size(0, 0)
        return
    end

    local main_max = horizontal and constraints.max_width or constraints.max_height
    local cross_max = horizontal and constraints.max_height or constraints.max_width

    local total_flex = 0
    for _, child in ipairs(children) do
        local flex = child.parent_data.flex or 0
        if flex > 0 then
            total_flex = total_flex + flex
        end
    end
    local has_flex = total_flex > 0 and main_max < huge

    local spacing_total = (n - 1) * self.spacing
    local used_main = 0
    local cross_size = 0

    for _, child in ipairs(children) do
        if not has_flex or (child.parent_data.flex or 0) <= 0 then
            child:layout(axis(horizontal, 0, main_max, 0, cross_max))
            used_main = used_main + (horizontal and child.size.width or child.size.height)
            cross_size = max(cross_size, horizontal and child.size.height or child.size.width)
        end
    end

    if has_flex then
        local free = max(0, main_max - used_main - spacing_total)
        for _, child in ipairs(children) do
            local flex = child.parent_data.flex or 0
            if flex > 0 then
                local extent = free * flex / total_flex
                child:layout(axis(horizontal, extent, extent, 0, cross_max))
                used_main = used_main + extent
                cross_size = max(cross_size, horizontal and child.size.height or child.size.width)
            end
        end
    end

    local content_main = used_main + spacing_total
    local own_main = has_flex and main_max or content_main
    self.size = constraints:constrain_size(
        horizontal and Size(own_main, cross_size) or Size(cross_size, own_main))

    local main_size = horizontal and self.size.width or self.size.height
    local own_cross = horizontal and self.size.height or self.size.width
    local free_main = max(0, main_size - content_main)

    local leading, gap_extra = 0, 0
    if self.main_alignment == 'center' then
        leading = free_main / 2
    elseif self.main_alignment == 'end' then
        leading = free_main
    elseif self.main_alignment == 'space_between' and n > 1 then
        gap_extra = free_main / (n - 1)
    end

    local cross_factor = factor(self.cross_alignment)
    local cursor = leading
    for _, child in ipairs(children) do
        local child_cross = horizontal and child.size.height or child.size.width
        local cross_offset = (own_cross - child_cross) * cross_factor
        if horizontal then
            child.parent_data.offset = Offset(cursor, cross_offset)
        else
            child.parent_data.offset = Offset(cross_offset, cursor)
        end
        cursor = cursor + (horizontal and child.size.width or child.size.height)
            + self.spacing + gap_extra
    end
end

M.RenderFlex = RenderFlex

return M
