-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Text styling (Flutter's `TextStyle`), backend agnostic.
--
-- A style carries only intent -- size, colour, weight, alignment, wrapping.
-- It never encodes a font file or an ASS override tag; backends translate it.

local std = require 'elxlibs.std'
local color_mod = require 'foundation.color'

local Color = color_mod.Color
local raise = std.raise

local M = {}

---@alias TextAlign
--- | 'left'
--- | 'center'
--- | 'right'

M.Align = {
    LEFT = 'left',
    CENTER = 'center',
    RIGHT = 'right',
}

--- Opaque backend extension data, immutable by convention and compared by identity.
--- The built-in ASS backend does not currently consume these extensions.
---@class TextStyleExtra : table<string,any>
---@field type string

---@class _TextStyleOptions
---@field font_size number?         non-negative finite logical pixels; default 16
---@field bold boolean?             default false
---@field color Color?              default 0xFFFFFFFF
---@field font_family string?
---@field italic boolean?           default false
---@field letter_spacing number?    finite extra px between glyphs; default 0
---@field line_height number?       non-negative finite multiple of font_size; default 1.2
---@field align TextAlign?          default 'left'
---@field wrap boolean?             default true
---@field extra TextStyleExtra?     immutable extension data for a supporting backend

---@type table<string, boolean>
local option_names = {
    font_size = true,
    color = true,
    font_family = true,
    bold = true,
    italic = true,
    letter_spacing = true,
    line_height = true,
    align = true,
    wrap = true,
    extra = true,
}

---@param options _TextStyleOptions?
---@return _TextStyleOptions
local function check_options(options)
    if options == nil then
        return {}
    end
    if type(options) ~= 'table' then
        raise(std.TypeError('TextStyle expects an options table'))
    end
    for name in pairs(options) do
        if not option_names[name] then
            raise(std.ValueError('unsupported TextStyle option: ' .. tostring(name)))
        end
    end
    return options
end

---@generic T
---@param value T?
---@param default T
---@return T
local function pick(value, default)
    if value == nil then
        return default
    end
    return value
end

---@param name string
---@param value number?
---@return number
local function check_finite(name, value)
    if type(value) ~= 'number' or value ~= value or value == math.huge or value == -math.huge then
        raise(std.ValueError('TextStyle.' .. name .. ' must be a finite number'))
    end
    return value
end

---@param name string
---@param value boolean?
---@return boolean
local function check_boolean(name, value)
    if type(value) ~= 'boolean' then
        raise(std.TypeError('TextStyle.' .. name .. ' must be a boolean'))
    end
    return value
end

---@class TextStyle : std.object
---@field font_size number
---@field color Color
---@field font_family string?
---@field bold boolean
---@field italic boolean
---@field letter_spacing number
---@field line_height number multiple of `font_size`
---@field align TextAlign
---@field wrap boolean
---@field extra TextStyleExtra?
---@overload fun(options: _TextStyleOptions?): self
local TextStyle = std.class.new('TextStyle')

---@param options _TextStyleOptions?
function TextStyle:__init(options)
    options = check_options(options)
    self.font_size = check_finite('font_size', pick(options.font_size, 16))
    self.color = pick(options.color, Color.argb(0xFFFFFFFF))
    self.font_family = options.font_family
    self.bold = check_boolean('bold', pick(options.bold, false))
    self.italic = check_boolean('italic', pick(options.italic, false))
    self.letter_spacing = check_finite('letter_spacing', pick(options.letter_spacing, 0))
    self.line_height = check_finite('line_height', pick(options.line_height, 1.2))
    self.align = pick(options.align, M.Align.LEFT)
    self.wrap = check_boolean('wrap', pick(options.wrap, true))
    self.extra = options.extra

    if self.font_size < 0 or self.line_height < 0 then
        raise(std.ValueError('TextStyle font_size and line_height must be non-negative'))
    end
    check_finite('line_height_px', self:line_height_px())
    if not std.isinstance(self.color, Color) then
        raise(std.TypeError('TextStyle.color must be a Color'))
    end
    if self.font_family ~= nil and type(self.font_family) ~= 'string' then
        raise(std.TypeError('TextStyle.font_family must be a string'))
    end
    if self.align ~= M.Align.LEFT and self.align ~= M.Align.CENTER and self.align ~= M.Align.RIGHT then
        raise(std.ValueError('TextStyle.align must be left, center or right'))
    end
    if self.extra ~= nil then
        if type(self.extra) ~= 'table' or type(self.extra.type) ~= 'string' or self.extra.type == '' then
            raise(std.TypeError('TextStyle.extra must be a table with a non-empty string type'))
        end
    end
end

function TextStyle:__tostring()
    return string.format('TextStyle(%g, %s)', self.font_size, self.font_family or 'default')
end

---@param other TextStyle
---@return boolean
function TextStyle:__eq(other)
    return not (self.font_size ~= other.font_size
        or self.color ~= other.color
        or self.font_family ~= other.font_family
        or self.bold ~= other.bold
        or self.italic ~= other.italic
        or self.letter_spacing ~= other.letter_spacing
        or self.line_height ~= other.line_height
        or self.align ~= other.align
        or self.wrap ~= other.wrap
        or not rawequal(self.extra, other.extra))
end

---@return number
function TextStyle:line_height_px()
    return self.font_size * self.line_height
end

--- Derive a copy with a subset of fields replaced.
---@param options _TextStyleOptions?
---@return TextStyle
function TextStyle:copy_with(options)
    options = check_options(options)
    return TextStyle({
        font_size = pick(options.font_size, self.font_size),
        color = pick(options.color, self.color),
        font_family = pick(options.font_family, self.font_family),
        bold = pick(options.bold, self.bold),
        italic = pick(options.italic, self.italic),
        letter_spacing = pick(options.letter_spacing, self.letter_spacing),
        line_height = pick(options.line_height, self.line_height),
        align = pick(options.align, self.align),
        wrap = pick(options.wrap, self.wrap),
        extra = pick(options.extra, self.extra),
    })
end

M.TextStyle = TextStyle

return M
