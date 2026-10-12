-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Multi-child box that lays children out along one axis (Flutter's
-- `RenderFlex`: `Row`, `Column`).
--
-- This is a faithful port of `RenderFlex.performLayout` (see
-- https://raw.githubusercontent.com/flutter/flutter/master/packages/flutter/lib/src/rendering/flex.dart):
--
--   1. Non-flex children are laid out with an *unbounded main axis* and the
--      incoming cross-axis constraints (tight on the cross axis when
--      `cross_alignment == 'stretch'`).
--   2. The remaining main-axis space is divided among the flex children by
--      their `parent_data.flex` weight. A child whose `parent_data.fit` is
--      `'tight'` (Expanded) is forced to fill its share; `'loose'` (Flexible)
--      may be smaller.
--   3. The cross extent is the largest child cross extent; the main extent is
--      the incoming max when it is bounded and `main_axis_size == 'max'`, else
--      the sum of the children.
--   4. Children are positioned by `main_alignment` / `cross_alignment`.
--
-- A non-zero flex on an unbounded main axis is an error (the doc's "you can't
-- use Expanded when the flex box is inside another flex box or a scrollable"),
-- exactly like Flutter's debug assertion. `main_axis_size == 'min'` with loose
-- fits is the supported way to shrink-wrap such a box.

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
local raise = std.raise

local M = {}

---@alias MainAlignment
--- | 'start'
--- | 'center'
--- | 'end'
--- | 'space_between'
--- | 'space_around'
--- | 'space_evenly'

---@alias MainAxisSize
--- | 'max'
--- | 'min'

---@alias CrossAlignment
--- | 'start'
--- | 'center'
--- | 'end'
--- | 'stretch'
--- | 'baseline'

---@class FlexOpts
---@field children RenderObject[]?
---@field main_alignment MainAlignment?
---@field main_axis_size MainAxisSize?
---@field cross_alignment CrossAlignment?
---@field spacing number?

---@alias FlexDirection
--- | 'row'
--- | 'column'

---@class RenderFlex : RenderObject
---@field direction FlexDirection
---@field main_alignment MainAlignment
---@field main_axis_size MainAxisSize
---@field cross_alignment CrossAlignment
---@field spacing number
---@overload fun(direction: FlexDirection, options: FlexOpts?): self
local RenderFlex = std.class.new('RenderFlex', { RenderObject })

function RenderFlex:__init(direction, options)
    RenderObject.__init(self)
    options = options or {}
    self.direction = direction or 'row'
    self.main_alignment = options.main_alignment or 'start'
    self.main_axis_size = options.main_axis_size or 'max'
    self.cross_alignment = options.cross_alignment or 'center'
    self.spacing = options.spacing or 0
    for _, child in ipairs(options.children or {}) do
        self:adopt_child(child)
    end
end

---@param horizontal boolean
---@param size Size
---@return number
local function main_extent(horizontal, size)
    return horizontal and size.width or size.height
end

---@param horizontal boolean
---@param size Size
---@return number
local function cross_extent(horizontal, size)
    return horizontal and size.height or size.width
end

---@param horizontal boolean
---@param main number
---@param cross number
---@return Size
local function axis_size(horizontal, main, cross)
    return horizontal and Size(main, cross) or Size(cross, main)
end

---@param horizontal boolean
---@param stretch boolean
---@param constraints Constraints
---@return Constraints
local function non_flex_constraints(horizontal, stretch, constraints)
    if horizontal then
        if stretch then
            return Constraints.tight_for({ height = constraints.max_height })
        end
        return Constraints(0, huge, 0, constraints.max_height)
    end
    if stretch then
        return Constraints.tight_for({ width = constraints.max_width })
    end
    return Constraints(0, constraints.max_width, 0, huge)
end

---@param horizontal boolean
---@param stretch boolean
---@param constraints Constraints
---@param min_extent number
---@param max_extent number
---@return Constraints
local function flex_child_constraints(horizontal, stretch, constraints, min_extent, max_extent)
    if horizontal then
        return Constraints(min_extent, max_extent,
            stretch and constraints.max_height or 0, constraints.max_height)
    end
    return Constraints(stretch and constraints.max_width or 0, constraints.max_width,
        min_extent, max_extent)
end

--- `MainAxisAlignment._distributeSpace` for a left-to-right / top-to-bottom
--- (non-flipped) flex.
---@param alignment string
---@param free number
---@param count integer
---@param spacing number
---@return number leading
---@return number between
local function distribute_space(alignment, free, count, spacing)
    if alignment == 'center' then
        return free / 2, spacing
    elseif alignment == 'end' then
        return free, spacing
    elseif alignment == 'space_between' then
        if count < 2 then
            return 0, spacing
        end
        return 0, free / (count - 1) + spacing
    elseif alignment == 'space_around' then
        if count == 0 then
            return 0, spacing
        end
        return free / count / 2, free / count + spacing
    elseif alignment == 'space_evenly' then
        return free / (count + 1), free / (count + 1) + spacing
    end
    -- 'start'
    return 0, spacing
end

--- `CrossAxisAlignment._getChildCrossAxisOffset` (non-flipped).
---@param alignment string
---@param free number
---@return number
local function cross_offset(alignment, free)
    if alignment == 'center' then
        return free / 2
    elseif alignment == 'end' then
        return free
    end
    -- 'start', 'stretch' and 'baseline' both sit at the cross-axis origin.
    return 0
end

---@param child RenderObject
---@return number
local function flex_of(child)
    return child.parent_data.flex or 0
end

---@param child RenderObject
---@return string
local function fit_of(child)
    return child.parent_data.fit or 'tight'
end

function RenderFlex:__perform_layout(constraints)
    local horizontal = self.direction == 'row'
    local children = self._children
    local n = #children
    local stretch = self.cross_alignment == 'stretch'

    local max_main = main_extent(horizontal, constraints:biggest())
    local can_flex = max_main < huge

    -- Non-zero flex on an unbounded main axis is an error (Flutter asserts).
    if not can_flex then
        for _, child in ipairs(children) do
            if flex_of(child) > 0
                and (self.main_axis_size == 'max' or fit_of(child) == 'tight') then
                local dimension = horizontal and 'width' or 'height'
                raise(std.RuntimeError(string.format(
                    'RenderFlex children have non-zero flex but incoming %s constraints are unbounded',
                    dimension)))
            end
        end
    end

    local non_flex = non_flex_constraints(horizontal, stretch, constraints)

    -- Spacing between children is part of the accumulated main extent.
    local accumulated_main = self.spacing * (n - 1)
    local accumulated_cross = 0
    local total_flex = 0

    -- Pass 1: lay out the inflexible children (and every child when the main
    -- axis is unbounded, where flex has no space to share).
    for _, child in ipairs(children) do
        local flex = can_flex and flex_of(child) or 0
        if flex > 0 then
            total_flex = total_flex + flex
        else
            child:layout(non_flex)
            accumulated_main = accumulated_main + main_extent(horizontal, child.size)
            accumulated_cross = max(accumulated_cross, cross_extent(horizontal, child.size))
        end
    end

    -- Pass 2: divide the free main-axis space among the flexible children.
    if total_flex > 0 then
        local free = max(0, max_main - accumulated_main)
        local space_per_flex = free / total_flex
        for _, child in ipairs(children) do
            local flex = flex_of(child)
            if flex > 0 then
                local max_child_extent = space_per_flex * flex
                local min_child_extent = fit_of(child) == 'tight' and max_child_extent or 0
                child:layout(flex_child_constraints(horizontal, stretch, constraints,
                    min_child_extent, max_child_extent))
                accumulated_main = accumulated_main + main_extent(horizontal, child.size)
                accumulated_cross = max(accumulated_cross, cross_extent(horizontal, child.size))
            end
        end
    end

    -- Main extent: fill the incoming max when bounded and main_axis_size is
    -- 'max'; otherwise shrink-wrap the children.
    local ideal_main
    if self.main_axis_size == 'max' and can_flex then
        ideal_main = max_main
    else
        ideal_main = accumulated_main
    end
    local size = constraints:constrain_size(axis_size(horizontal, ideal_main, accumulated_cross))
    self.size = size

    local own_main = main_extent(horizontal, size)
    local own_cross = cross_extent(horizontal, size)
    local remaining = max(0, own_main - accumulated_main)
    local leading, between = distribute_space(self.main_alignment, remaining, n, self.spacing)

    local cursor = leading
    for _, child in ipairs(children) do
        local child_cross = cross_extent(horizontal, child.size)
        local child_cross_offset = cross_offset(self.cross_alignment, own_cross - child_cross)
        if horizontal then
            child.parent_data.offset = Offset(cursor, child_cross_offset)
        else
            child.parent_data.offset = Offset(child_cross_offset, cursor)
        end
        cursor = cursor + main_extent(horizontal, child.size) + between
    end
end

M.RenderFlex = RenderFlex

return M
