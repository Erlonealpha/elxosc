-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Value interpolation for animation properties.

local std = require 'elxlibs.std'
local geometry = require 'foundation.geometry'
local color_mod = require 'foundation.color'

local Offset = geometry.Offset
local Size = geometry.Size
local Color = color_mod.Color
local raise = std.raise

local M = {}

---@param begin_value any
---@param end_value any
---@param t number
---@return any
local function default_lerp(begin_value, end_value, t)
    if type(begin_value) == 'number' and type(end_value) == 'number' then
        return begin_value + (end_value - begin_value) * t
    end
    if type(begin_value) == 'table' and type(end_value) == 'table'
        and type(begin_value.x) == 'number' and type(begin_value.y) == 'number'
        and type(end_value.x) == 'number' and type(end_value.y) == 'number' then
        return Offset(
            begin_value.x + (end_value.x - begin_value.x) * t,
            begin_value.y + (end_value.y - begin_value.y) * t)
    end
    if type(begin_value) == 'table' and type(end_value) == 'table'
        and type(begin_value.width) == 'number' and type(begin_value.height) == 'number'
        and type(end_value.width) == 'number' and type(end_value.height) == 'number' then
        return Size(
            begin_value.width + (end_value.width - begin_value.width) * t,
            begin_value.height + (end_value.height - begin_value.height) * t)
    end
    if type(begin_value) == 'table' and type(end_value) == 'table'
        and type(begin_value.r) == 'number' and type(begin_value.g) == 'number'
        and type(begin_value.b) == 'number' and type(begin_value.a) == 'number'
        and type(end_value.r) == 'number' and type(end_value.g) == 'number'
        and type(end_value.b) == 'number' and type(end_value.a) == 'number' then
        return Color(
            begin_value.r + (end_value.r - begin_value.r) * t,
            begin_value.g + (end_value.g - begin_value.g) * t,
            begin_value.b + (end_value.b - begin_value.b) * t,
            begin_value.a + (end_value.a - begin_value.a) * t)
    end
    if t <= 0 then
        return begin_value
    elseif t >= 1 then
        return end_value
    end
    raise(std.TypeError('Tween needs numbers or matching geometry/colour values'))
end

---@class Tween : std.object
---@field begin_value any
---@field end_value any
---@field lerp fun(begin_value: any, end_value: any, t: number): any
---@overload fun(begin_value: any, end_value: any, lerp?: fun(begin_value: any, end_value: any, t: number): any): Tween
local Tween = std.class.new('Tween')

---@param begin_value any
---@param end_value any
---@param lerp fun(begin_value: any, end_value: any, t: number): any?
function Tween:__init(begin_value, end_value, lerp)
    self.begin_value = begin_value
    self.end_value = end_value
    self.lerp = lerp or default_lerp
end

---@param t number
---@return any
function Tween:value_at(t)
    return self.lerp(self.begin_value, self.end_value, t)
end

---@param begin_value number
---@param end_value number
---@return Tween
function Tween.number(begin_value, end_value)
    return Tween(begin_value, end_value)
end

---@param begin_value Offset
---@param end_value Offset
---@return Tween
function Tween.offset(begin_value, end_value)
    return Tween(begin_value, end_value)
end

M.Tween = Tween

return M
