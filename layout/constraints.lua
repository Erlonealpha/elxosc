-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Layout constraints (Flutter's `BoxConstraints`).
--
-- The whole layout protocol hangs off this value type: a parent passes
-- `Constraints` down, the child returns a `Size` up, and the parent decides the
-- position. See "Constraints go down. Sizes go up. Parent sets position."

local std = require 'elxlibs.std'
local geometry = require 'foundation.geometry'

local Size = geometry.Size
local math = math
local min = math.min
local max = math.max
local huge = math.huge

---@class elxconstraints
local M = {}

---@class Constraints : std.object
---@field min_width number
---@field max_width number
---@field min_height number
---@field max_height number
---@overload fun(min_width: number?, max_width: number?, min_height: number?, max_height: number?): Constraints
local Constraints = std.class.new('Constraints')

function Constraints:__init(min_width, max_width, min_height, max_height)
    self.min_width = min_width or 0
    self.max_width = max_width or huge
    self.min_height = min_height or 0
    self.max_height = max_height or huge
end

function Constraints:__tostring()
    return string.format('Constraints(%g..%g, %g..%g)',
        self.min_width, self.max_width, self.min_height, self.max_height)
end

---@param other Constraints
---@return boolean
function Constraints:__eq(other)
    return self.min_width == other.min_width and self.max_width == other.max_width
        and self.min_height == other.min_height and self.max_height == other.max_height
end

---@param value number
---@return number
function Constraints:constrain_width(value)
    return min(max(value, self.min_width), self.max_width)
end

---@param value number
---@return number
function Constraints:constrain_height(value)
    return min(max(value, self.min_height), self.max_height)
end

---@param size Size
---@return Size
function Constraints:constrain_size(size)
    return Size(self:constrain_width(size.width), self:constrain_height(size.height))
end

---@return boolean
function Constraints:has_bounded_width()
    return self.max_width < huge
end

---@return boolean
function Constraints:has_bounded_height()
    return self.max_height < huge
end

---@return boolean
function Constraints:is_tight()
    return self.min_width == self.max_width and self.min_height == self.max_height
end

---@return boolean
function Constraints:is_normalized()
    return self.min_width <= self.max_width and self.min_height <= self.max_height
end

--- Shrink by insets (the inverse of a padding box). Never goes negative.
---@param insets EdgeInsets
---@return Constraints
function Constraints:deflate(insets)
    local h = insets:horizontal()
    local v = insets:vertical()
    return Constraints(
        max(0, self.min_width - h), max(0, self.max_width - h),
        max(0, self.min_height - v), max(0, self.max_height - v))
end

--- Relax the minimums to zero so a child may be smaller than us.
---@return Constraints
function Constraints:loosen()
    return Constraints(0, self.max_width, 0, self.max_height)
end

---@param width number
---@param height number
---@return Constraints
function Constraints.tight(width, height)
    return Constraints(width, width, height, height)
end

---@param size Size
---@return Constraints
function Constraints.tight_size(size)
    return Constraints(size.width, size.width, size.height, size.height)
end

---@param width number
---@param height number
---@return Constraints
function Constraints.loose(width, height)
    return Constraints(0, width or huge, 0, height or huge)
end

---@return Constraints
function Constraints.expand()
    return Constraints(0, huge, 0, huge)
end

M.Constraints = Constraints

return M
