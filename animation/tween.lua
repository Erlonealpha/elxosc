-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Value interpolation for animation properties.

local std = require 'elxlibs.std'
local geometry = require 'foundation.geometry'
local color_mod = require 'foundation.color'

local type = type
local ipairs = ipairs
local Offset = geometry.Offset
local Size = geometry.Size
local Color = color_mod.Color
local raise = std.raise

local M = {}

---@alias TweenSupportedValue
--- | number
--- | { x: number, y: number }
--- | { width: number, height: number }
--- | { r: number, g: number, b: number, a: number }

---@alias TweenSupportedTypes
--- | 'number'
--- | 'Offset'
--- | 'Size'
--- | 'Color'


---@return TweenSupportedTypes
local function type_detect(begin_value, end_value)
    local function all_is_number(...)
        -- use it to return early, but must avoid overlapping target types fields.
        local match_one = false
        for _, key in ipairs({...}) do
            if type(begin_value[key]) ~= 'number' or type(end_value[key]) ~= 'number' then
                return false, match_one
            end
            match_one = true
        end
        return true
    end
    local begin_typ = type(begin_value)
    local end_typ = type(end_value)
    if begin_typ == 'number' and end_typ == 'number' then
        return 'number'
    end
    repeat
        if begin_typ == 'table' and end_typ == 'table' then
            local is_offset, _ = all_is_number('x', 'y')
            if is_offset then
                return 'Offset'
            elseif _ then
                break
            end
            local is_size, _ = all_is_number('width', 'height')
            if is_size then
                return 'Size'
            elseif _ then
                break
            end
            local is_color, _ = all_is_number('r', 'g', 'b', 'a')
            if is_color then
                return 'Color'
            elseif _ then
                break
            end
        end
    until true
    raise(std.TypeError('Tween needs numbers or matching geometry/colour values'))
end

---@param begin_value TweenSupportedValue
---@param end_value TweenSupportedValue
---@param t number
---@param typ TweenSupportedTypes
---@return any
local function default_lerp(begin_value, end_value, t, typ)
    ---@cast begin_value any
    ---@cast end_value any
    if typ == 'number' then
        return begin_value + (end_value - begin_value) * t
    end
    if typ == 'Offset' then
        return Offset(
            begin_value.x + (end_value.x - begin_value.x) * t,
            begin_value.y + (end_value.y - begin_value.y) * t)
    end
    if typ == 'Size' then
        return Size(
            begin_value.width + (end_value.width - begin_value.width) * t,
            begin_value.height + (end_value.height - begin_value.height) * t)
    end
    if typ == 'Color' then
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

---@class Tween<T : TweenSupportedValue> : std.object
---@field begin_value TweenSupportedValue
---@field end_value TweenSupportedValue
---@field lerp fun(begin_value: T, end_value: T, t: number, typ: TweenSupportedTypes): T
---@overload fun(begin_value: T, end_value: T, lerp?: fun(begin_value: T, end_value: T, t: number, typ: TweenSupportedTypes): T): self
local Tween = std.class.new('Tween', {})

---@param begin_value T
---@param end_value T
---@param lerp (fun(begin_value: T, end_value: T, t: number): T)?
function Tween:__init(begin_value, end_value, lerp)
    self._type = lerp == nil and type_detect(begin_value, end_value) or 'number'
    self.begin_value = begin_value
    self.end_value = end_value
    if lerp then
        self.lerp = function(custom_begin, custom_end, t, _typ)
            return lerp(custom_begin, custom_end, t)
        end
    else
        self.lerp = default_lerp
    end
end

---@param t number
---@return T
function Tween:value_at(t)
    return self.lerp(self.begin_value, self.end_value, t, self._type)
end

---@param begin_value number
---@param end_value number
---@return Tween<T>
function Tween.number(begin_value, end_value)
    return Tween(begin_value, end_value)
end

---@param begin_value Offset
---@param end_value Offset
---@return Tween<T>
function Tween.offset(begin_value, end_value)
    return Tween(begin_value, end_value)
end

M.Tween = Tween

return M
