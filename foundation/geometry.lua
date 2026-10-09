-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Foundation geometry primitives (backend agnostic).
--
-- Offset / Size / Rect / EdgeInsets are the shared vocabulary of layout,
-- painting and hit testing. They are immutable by convention: every helper
-- returns a new value instead of mutating its receiver, so a rendered frame
-- never mutates geometry that an ancestor still depends on.
--
-- Value semantics (__eq / __add / __sub / __mul) are provided so layout math
-- reads like the Flutter render layer, e.g. `rect.size() + padding`.

local std = require 'elxlibs.std'

local math = math
local string = string
local sqrt = math.sqrt
local min = math.min
local max = math.max
local format = string.format

---@class elxgeometry
local M = {}

--==========================================================================
-- Offset
--==========================================================================

---@class Offset : std.object
---@field x number
---@field y number
---@overload fun(x: number?, y: number?): Offset
local Offset = std.class.new('Offset')

function Offset:__init(x, y)
    self.x = x or 0
    self.y = y or 0
end

function Offset:__tostring()
    return format('Offset(%g, %g)', self.x, self.y)
end

---@param other Offset
---@return boolean
function Offset:__eq(other)
    return self.x == other.x and self.y == other.y
end

---@param other Offset
---@return Offset
function Offset:__add(other)
    return Offset(self.x + other.x, self.y + other.y)
end

---@param other Offset
---@return Offset
function Offset:__sub(other)
    return Offset(self.x - other.x, self.y - other.y)
end

---@param factor number
---@return Offset
function Offset:__mul(factor)
    return Offset(self.x * factor, self.y * factor)
end

---@return Offset
function Offset:__unm()
    return Offset(-self.x, -self.y)
end

---@param dx number
---@param dy number
---@return Offset
function Offset:translate(dx, dy)
    return Offset(self.x + dx, self.y + dy)
end

---@param sx number
---@param sy number? defaults to `sx`
---@return Offset
function Offset:scale(sx, sy)
    return Offset(self.x * sx, self.y * (sy or sx))
end

---@return number
function Offset:length()
    return sqrt(self.x * self.x + self.y * self.y)
end

---@param other Offset
---@return number
function Offset:distance(other)
    local dx = self.x - other.x
    local dy = self.y - other.y
    return sqrt(dx * dx + dy * dy)
end

---@return Offset
function Offset.zero()
    return Offset(0, 0)
end

--==========================================================================
-- Size
--==========================================================================

---@class Size : std.object
---@field width number
---@field height number
---@overload fun(width: number?, height: number?): Size
local Size = std.class.new('Size')

function Size:__init(width, height)
    self.width = width or 0
    self.height = height or 0
end

function Size:__tostring()
    return format('Size(%g, %g)', self.width, self.height)
end

---@param other Size
---@return boolean
function Size:__eq(other)
    return self.width == other.width and self.height == other.height
end

---@param other Size
---@return Size
function Size:__add(other)
    return Size(self.width + other.width, self.height + other.height)
end

---@param other Size
---@return Size
function Size:__sub(other)
    return Size(self.width - other.width, self.height - other.height)
end

---@param factor number
---@return Size
function Size:__mul(factor)
    return Size(self.width * factor, self.height * factor)
end

---@return number
function Size:aspect_ratio()
    if self.height == 0 then
        return 1
    end
    return self.width / self.height
end

---@return number
function Size:area()
    return self.width * self.height
end

---@return boolean
function Size:is_empty()
    return self.width <= 0 or self.height <= 0
end

---@return Size
function Size.zero()
    return Size(0, 0)
end

---@param extent number
---@return Size
function Size.square(extent)
    return Size(extent, extent)
end

--==========================================================================
-- Rect
--==========================================================================

--- A rectangle stored as left/top/right/bottom edges (Flutter's LTRB form).
---@class Rect : std.object
---@field left number
---@field top number
---@field right number
---@field bottom number
---@overload fun(left: number?, top: number?, right: number?, bottom: number?): Rect
local Rect = std.class.new('Rect')

function Rect:__init(left, top, right, bottom)
    self.left = left or 0
    self.top = top or 0
    self.right = right or 0
    self.bottom = bottom or 0
end

function Rect:__tostring()
    return format('Rect(%g, %g, %g, %g)', self.left, self.top, self.right, self.bottom)
end

---@param other Rect
---@return boolean
function Rect:__eq(other)
    return self.left == other.left and self.top == other.top
        and self.right == other.right and self.bottom == other.bottom
end

---@return number
function Rect:width()
    return self.right - self.left
end

---@return number
function Rect:height()
    return self.bottom - self.top
end

---@return Size
function Rect:size()
    return Size(self:width(), self:height())
end

---@return Offset
function Rect:top_left()
    return Offset(self.left, self.top)
end

---@return Offset
function Rect:center()
    return Offset((self.left + self.right) / 2, (self.top + self.bottom) / 2)
end

---@return boolean
function Rect:is_empty()
    return self.left >= self.right or self.top >= self.bottom
end

--- Half-open test (`right`/`bottom` are exclusive), matching Flutter.
---@param offset Offset
---@return boolean
function Rect:contains(offset)
    return offset.x >= self.left and offset.x < self.right
        and offset.y >= self.top and offset.y < self.bottom
end

---@param delta number
---@return Rect
function Rect:inflate(delta)
    return Rect(self.left - delta, self.top - delta, self.right + delta, self.bottom + delta)
end

---@param delta number
---@return Rect
function Rect:deflate(delta)
    return self:inflate(-delta)
end

---@param offset Offset
---@return Rect
function Rect:shift(offset)
    return Rect(self.left + offset.x, self.top + offset.y,
        self.right + offset.x, self.bottom + offset.y)
end

---@param dx number
---@param dy number
---@return Rect
function Rect:translate(dx, dy)
    return Rect(self.left + dx, self.top + dy, self.right + dx, self.bottom + dy)
end

---@param other Rect
---@return boolean
function Rect:overlaps(other)
    return self.left < other.right and other.left < self.right
        and self.top < other.bottom and other.top < self.bottom
end

--- Overlap of two rects; the result is empty when they do not intersect.
---@param other Rect
---@return Rect
function Rect:intersect(other)
    local left = max(self.left, other.left)
    local top = max(self.top, other.top)
    local right = min(self.right, other.right)
    local bottom = min(self.bottom, other.bottom)
    if right <= left or bottom <= top then
        return Rect(left, top, left, top)
    end
    return Rect(left, top, right, bottom)
end

---@param left number
---@param top number
---@param width number
---@param height number
---@return Rect
function Rect.from_ltwh(left, top, width, height)
    return Rect(left, top, left + width, top + height)
end

---@param left number
---@param top number
---@param right number
---@param bottom number
---@return Rect
function Rect.from_ltrb(left, top, right, bottom)
    return Rect(left, top, right, bottom)
end

---@param a Offset
---@param b Offset
---@return Rect
function Rect.from_points(a, b)
    return Rect(min(a.x, b.x), min(a.y, b.y), max(a.x, b.x), max(a.y, b.y))
end

---@param offset Offset
---@param size Size
---@return Rect
function Rect.from_offset_size(offset, size)
    return Rect(offset.x, offset.y, offset.x + size.width, offset.y + size.height)
end

--==========================================================================
-- EdgeInsets
--==========================================================================

---@class EdgeInsets : std.object
---@field left number
---@field top number
---@field right number
---@field bottom number
---@overload fun(left: number?, top: number?, right: number?, bottom: number?): EdgeInsets
local EdgeInsets = std.class.new('EdgeInsets')

function EdgeInsets:__init(left, top, right, bottom)
    self.left = left or 0
    self.top = top or 0
    self.right = right or 0
    self.bottom = bottom or 0
end

function EdgeInsets:__tostring()
    return format('EdgeInsets(%g, %g, %g, %g)', self.left, self.top, self.right, self.bottom)
end

---@param other EdgeInsets
---@return boolean
function EdgeInsets:__eq(other)
    return self.left == other.left and self.top == other.top
        and self.right == other.right and self.bottom == other.bottom
end

---@return number
function EdgeInsets:horizontal()
    return self.left + self.right
end

---@return number
function EdgeInsets:vertical()
    return self.top + self.bottom
end

---@return Offset
function EdgeInsets:top_left()
    return Offset(self.left, self.top)
end

---@return Offset
function EdgeInsets:bottom_right()
    return Offset(self.right, self.bottom)
end

--- Grow `rect` by these insets (padding/outer box).
---@param rect Rect
---@return Rect
function EdgeInsets:inflate_rect(rect)
    return Rect(rect.left - self.left, rect.top - self.top,
        rect.right + self.right, rect.bottom + self.bottom)
end

--- Shrink `rect` by these insets (the content box of a padded container).
---@param rect Rect
---@return Rect
function EdgeInsets:deflate_rect(rect)
    return Rect(rect.left + self.left, rect.top + self.top,
        rect.right - self.right, rect.bottom - self.bottom)
end

---@param value number
---@return EdgeInsets
function EdgeInsets.all(value)
    return EdgeInsets(value, value, value, value)
end

---@param horizontal number
---@param vertical number
---@return EdgeInsets
function EdgeInsets.symmetric(horizontal, vertical)
    return EdgeInsets(horizontal, vertical, horizontal, vertical)
end

---@param options { left?: number, top?: number, right?: number, bottom?: number }
---@return EdgeInsets
function EdgeInsets.only(options)
    options = options or {}
    return EdgeInsets(options.left or 0, options.top or 0, options.right or 0, options.bottom or 0)
end

---@return EdgeInsets
function EdgeInsets.zero()
    return EdgeInsets(0, 0, 0, 0)
end

M.Offset = Offset
M.Size = Size
M.Rect = Rect
M.EdgeInsets = EdgeInsets

return M
