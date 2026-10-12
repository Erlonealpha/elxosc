-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Backend agnostic RGBA colour value.
--
-- Components are stored as 0..1 numbers so the framework never bakes in a
-- particular bit depth. Render backends convert to their own encoding (ASS
-- `&HAABBGGRR`, a mpv.net surface pixel, ...) -- the framework itself has no
-- notion of "ass colour" or "bgr".

local std = require 'elxlibs.std'

local raise = std.raise
local math = math
local string = string
local floor = math.floor
local format = string.format

local M = {}

---@param channel number 0..1
---@return number 0..255
local function to_byte(channel)
    return floor(channel * 255 + 0.5)
end

---@class Color : std.object
---@field r number 0..1
---@field g number 0..1
---@field b number 0..1
---@field a number 0..1 (1 = opaque)
---@overload fun(r: number?, g: number?, b: number?, a: number?): self
local Color = std.class.new('Color', {})

function Color:__init(r, g, b, a)
    self.r = r or 0
    self.g = g or 0
    self.b = b or 0
    self.a = a == nil and 1 or a
end

function Color:__tostring()
    return format('Color(%.3f, %.3f, %.3f, %.3f)', self.r, self.g, self.b, self.a)
end

---@param other Color
---@return boolean
function Color:__eq(other)
    return self.r == other.r and self.g == other.g
        and self.b == other.b and self.a == other.a
end

---@param alpha number 0..1
---@return Color
function Color:with_alpha(alpha)
    return Color(self.r, self.g, self.b, alpha)
end

---@param r number 0..1
---@param g number 0..1
---@param b number 0..1
---@return Color
function Color:with_rgb(r, g, b)
    return Color(r, g, b, self.a)
end

---@return number r 0..255
---@return number g 0..255
---@return number b 0..255
---@return number a 0..255
function Color:to_rgba255()
    return to_byte(self.r), to_byte(self.g), to_byte(self.b), to_byte(self.a)
end

---@param r number 0..255
---@param g number 0..255
---@param b number 0..255
---@param a number? 0..255, defaults to 255
---@return Color
function Color.rgba255(r, g, b, a)
    return Color(r / 255, g / 255, b / 255, (a ~= nil and a or 255) / 255)
end

--- 32 bit `0xAARRGGBB` (Flutter's `Color.value` / RGB layout).
---@param argb integer
---@return Color
function Color.argb(argb)
    local a = floor(argb / 0x1000000) % 256
    local r = floor(argb / 0x10000) % 256
    local g = floor(argb / 0x100) % 256
    local b = argb % 256
    return Color.rgba255(r, g, b, a)
end

--- 32 bit `0xRRGGBBAA`.
---@param rgba integer
---@return Color
function Color.rgba(rgba)
    local r = floor(rgba / 0x1000000) % 256
    local g = floor(rgba / 0x10000) % 256
    local b = floor(rgba / 0x100) % 256
    local a = rgba % 256
    return Color.rgba255(r, g, b, a)
end

--- CSS style hex: `#RGB`, `#RGBA`, `#RRGGBB` or `#RRGGBBAA` (alpha defaults
--- to opaque). The leading `#` is optional.
---@param hex string
---@return Color
function Color.hex(hex)
    local s = hex:gsub('#', '')
    local function part(i, width)
        local digits = s:sub(i, i + width - 1)
        if width == 1 then
            digits = digits .. digits
        end
        return tonumber(digits, 16) or 0
    end
    local len = #s
    if len == 3 or len == 4 then
        return Color.rgba255(part(1, 1), part(2, 1), part(3, 1), len == 4 and part(4, 1) or 255)
    end
    if len == 6 or len == 8 then
        return Color.rgba255(part(1, 2), part(3, 2), part(5, 2), len == 8 and part(7, 2) or 255)
    end
    raise(std.ValueError('invalid hex colour: ' .. tostring(hex)))
end

M.Color = Color

return M
