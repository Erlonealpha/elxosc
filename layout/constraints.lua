-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Layout constraints (Flutter's `BoxConstraints`).
--
-- The whole layout protocol hangs off this value type: a parent passes
-- `Constraints` down, the child returns a `Size` up, and the parent decides the
-- position. See "Constraints go down. Sizes go up. Parent sets position."
--
-- The vocabulary mirrors `BoxConstraints` exactly (see
-- https://api.flutter.dev/flutter/rendering/BoxConstraints-class.html):
--   * bounded   -> `max < infinity`
--   * loose     -> `min == 0`
--   * tight     -> `min == max`
--   * expanding -> tightly infinite (both `min` and `max` are infinity)
--   * infinite  -> `min == infinity` implies the axis is expanding
-- `enforce` is the "only impose ADDITIONAL constraints" primitive the
-- `ConstrainedBox` / `SizedBox` family is built on; `expand` is the tightly
-- infinite constructor `BoxConstraints.expand()` and is *not* the same as an
-- unbounded (0..infinity) box, which is spelled `unbounded()` here.

local std = require 'elxlibs.std'
local geometry = require 'foundation.geometry'

local Size = geometry.Size
local math = math
local min = math.min
local max = math.max
local huge = math.huge

local M = {}

---@param value number
---@param low number
---@param high number
---@return number
local function clamp(value, low, high)
    if value < low then
        return low
    end
    if value > high then
        return high
    end
    return value
end

---@class Constraints : std.object
---@field min_width number
---@field max_width number
---@field min_height number
---@field max_height number
---@overload fun(min_width: number?, max_width: number?, min_height: number?, max_height: number?): self
local Constraints = std.class.new('Constraints', {})

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

--- True when the axis is infinite (its minimum is already infinity). An
--- infinite axis is necessarily also expanding (tight to infinity).
---@return boolean
function Constraints:has_infinite_width()
    return self.min_width >= huge
end

---@return boolean
function Constraints:has_infinite_height()
    return self.min_height >= huge
end

---@return boolean
function Constraints:has_tight_width()
    return self.min_width == self.max_width
end

---@return boolean
function Constraints:has_tight_height()
    return self.min_height == self.max_height
end

--- The biggest / smallest size that still satisfies these constraints
--- (Flutter's `BoxConstraints.biggest` / `smallest`).
---@return Size
function Constraints:biggest()
    return Size(self.max_width, self.max_height)
end

---@return Size
function Constraints:smallest()
    return Size(self.min_width, self.min_height)
end

---@return boolean
function Constraints:is_tight()
    return self.min_width == self.max_width and self.min_height == self.max_height
end

---@return boolean
function Constraints:is_normalized()
    return self.min_width <= self.max_width and self.min_height <= self.max_height
end

---@param size Size
---@return boolean
function Constraints:is_satisfied_by(size)
    return self.min_width <= size.width and size.width <= self.max_width
        and self.min_height <= size.height and size.height <= self.max_height
end

--- The "only impose ADDITIONAL constraints" operator: each of our four values
--- is clamped into the incoming range, so the result is the intersection of
--- both constraint sets (Flutter's `BoxConstraints.enforce`).
---@param constraints Constraints
---@return Constraints
function Constraints:enforce(constraints)
    return Constraints(
        clamp(self.min_width, constraints.min_width, constraints.max_width),
        clamp(self.max_width, constraints.min_width, constraints.max_width),
        clamp(self.min_height, constraints.min_height, constraints.max_height),
        clamp(self.max_height, constraints.min_height, constraints.max_height))
end

--- Tighten one or both axes to a specific value, as close as the current
--- constraints allow (Flutter's `BoxConstraints.tighten`).
---@param options { width?: number, height?: number }?
---@return Constraints
function Constraints:tighten(options)
    options = options or {}
    local width = options.width
    local height = options.height
    local min_width, max_width = self.min_width, self.max_width
    local min_height, max_height = self.min_height, self.max_height
    if width ~= nil then
        min_width = clamp(width, self.min_width, self.max_width)
        max_width = min_width
    end
    if height ~= nil then
        min_height = clamp(height, self.min_height, self.max_height)
        max_height = min_height
    end
    return Constraints(min_width, max_width, min_height, max_height)
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

--- Force the constraints to be normalized (min <= max on both axes).
---@return Constraints
function Constraints:normalize()
    if self:is_normalized() then
        return self
    end
    local min_width = clamp(self.min_width, 0, huge)
    local max_width = clamp(self.max_width, min_width, huge)
    local min_height = clamp(self.min_height, 0, huge)
    local max_height = clamp(self.max_height, min_height, huge)
    return Constraints(min_width, max_width, min_height, max_height)
end

--- Shrink a preferred size so it fits while preserving its aspect ratio
--- (Flutter's `constrainSizeAndAttemptToPreserveAspectRatio`), the sizing rule
--- behind `FittedBox`.
---@param size Size
---@return Size
function Constraints:constrain_size_and_attempt_to_preserve_aspect_ratio(size)
    if self:is_tight() then
        return self:smallest()
    end
    local width = size.width
    local height = size.height
    if width > self.max_width then
        height = height * self.max_width / width
        width = self.max_width
    end
    if height > self.max_height then
        width = width * self.max_height / height
        height = self.max_height
    end
    return Size(width, height)
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

--- The unbounded box: any size from zero up to infinity. This is Flutter's
--- default `BoxConstraints()`; it is what `UnconstrainedBox` hands down.
---@return Constraints
function Constraints.unbounded()
    return Constraints(0, huge, 0, huge)
end

--- A box that requires exactly `width`/`height`, defaulting to infinity, so it
--- expands to fill whatever parent constraint it is enforced against
--- (Flutter's `BoxConstraints.expand`). The tightly-infinite constraints it
--- builds are only ever meaningful once passed through `enforce`, which is
--- exactly how `Container`'s childless branch and `SizedBox.expand` use it.
---@param width number?
---@param height number?
---@return Constraints
function Constraints.expand(width, height)
    return Constraints(width or huge, width or huge, height or huge, height or huge)
end

--- Tight on the axes that are given, unbounded (0..infinity) on the others
--- (Flutter's `BoxConstraints.tightFor`).
---@param options { width?: number, height?: number }?
---@return Constraints
function Constraints.tight_for(options)
    options = options or {}
    local width = options.width
    local height = options.height
    return Constraints(
        width == nil and 0 or width, width == nil and huge or width,
        height == nil and 0 or height, height == nil and huge or height)
end

M.Constraints = Constraints

return M
