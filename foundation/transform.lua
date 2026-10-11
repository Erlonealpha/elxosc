-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Two-dimensional affine transforms for logical rendering coordinates.
--
-- Matrices use column vectors and are stored as:
--
--     x' = a*x + c*y + tx
--     y' = b*x + d*y + ty
--
-- `multiply` returns `self * other`, so the returned transform applies `other`
-- first and `self` second. The type is backend agnostic: being able to express
-- a transform does not imply that a concrete backend can render every one.

local std = require 'elxlibs.std'
local geometry = require 'foundation.geometry'

local Offset = geometry.Offset
local Rect = geometry.Rect
local min = math.min
local max = math.max
local format = string.format

local M = {}

---@class Matrix2D : std.object
---@field a number x basis x component
---@field b number y basis x component
---@field c number x basis y component
---@field d number y basis y component
---@field tx number x translation
---@field ty number y translation
---@overload fun(a: number?, b: number?, c: number?, d: number?, tx: number?, ty: number?): Matrix2D
local Matrix2D = std.class.new('Matrix2D')

---@param a number?
---@param b number?
---@param c number?
---@param d number?
---@param tx number?
---@param ty number?
function Matrix2D:__init(a, b, c, d, tx, ty)
    self.a = a == nil and 1 or a
    self.b = b == nil and 0 or b
    self.c = c == nil and 0 or c
    self.d = d == nil and 1 or d
    self.tx = tx == nil and 0 or tx
    self.ty = ty == nil and 0 or ty
end

function Matrix2D:__tostring()
    return format('Matrix2D(%g, %g, %g, %g, %g, %g)',
        self.a, self.b, self.c, self.d, self.tx, self.ty)
end

---@param other Matrix2D
---@return boolean
function Matrix2D:__eq(other)
    return self.a == other.a and self.b == other.b
        and self.c == other.c and self.d == other.d
        and self.tx == other.tx and self.ty == other.ty
end

---@return Matrix2D
function Matrix2D.identity()
    return Matrix2D(1, 0, 0, 1, 0, 0)
end

---@param dx number
---@param dy number
---@return Matrix2D
function Matrix2D.translation(dx, dy)
    return Matrix2D(1, 0, 0, 1, dx, dy)
end

---@param sx number
---@param sy number?
---@return Matrix2D
function Matrix2D.scale(sx, sy)
    return Matrix2D(sx, 0, 0, sy == nil and sx or sy, 0, 0)
end

---@param other Matrix2D
---@return Matrix2D
function Matrix2D:multiply(other)
    return Matrix2D(
        self.a * other.a + self.c * other.b,
        self.b * other.a + self.d * other.b,
        self.a * other.c + self.c * other.d,
        self.b * other.c + self.d * other.d,
        self.a * other.tx + self.c * other.ty + self.tx,
        self.b * other.tx + self.d * other.ty + self.ty)
end

---@param point Offset
---@return Offset
function Matrix2D:transform_offset(point)
    return Offset(
        self.a * point.x + self.c * point.y + self.tx,
        self.b * point.x + self.d * point.y + self.ty)
end

---@param point Offset
---@return Offset
function Matrix2D:transform_point(point)
    return self:transform_offset(point)
end

---@param rect Rect
---@return Rect axis-aligned bounds of the transformed corners
function Matrix2D:transform_rect(rect)
    local top_left = self:transform_offset(Offset(rect.left, rect.top))
    local top_right = self:transform_offset(Offset(rect.right, rect.top))
    local bottom_left = self:transform_offset(Offset(rect.left, rect.bottom))
    local bottom_right = self:transform_offset(Offset(rect.right, rect.bottom))
    return Rect(
        min(top_left.x, top_right.x, bottom_left.x, bottom_right.x),
        min(top_left.y, top_right.y, bottom_left.y, bottom_right.y),
        max(top_left.x, top_right.x, bottom_left.x, bottom_right.x),
        max(top_left.y, top_right.y, bottom_left.y, bottom_right.y))
end

---@return number
function Matrix2D:determinant()
    return self.a * self.d - self.b * self.c
end

--- Return nil for a singular or non-finite transform instead of inventing an
--- inverse. Callers that need input mapping must handle this explicitly.
---@return Matrix2D?
function Matrix2D:inverse()
    local determinant = self:determinant()
    if determinant == 0 or determinant ~= determinant
        or determinant == math.huge or determinant == -math.huge then
        return nil
    end
    return Matrix2D(
        self.d / determinant,
        -self.b / determinant,
        -self.c / determinant,
        self.a / determinant,
        (self.c * self.ty - self.d * self.tx) / determinant,
        (self.b * self.tx - self.a * self.ty) / determinant)
end

---@return boolean
function Matrix2D:is_identity()
    return self == Matrix2D.identity()
end

M.Matrix2D = Matrix2D

return M
