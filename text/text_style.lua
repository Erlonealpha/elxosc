-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Text styling (Flutter's `TextStyle`), backend agnostic.
--
-- A style carries only intent -- size, colour, weight, alignment, wrapping.
-- It never encodes a font file or an ASS override tag; backends translate it.

local std = require 'elxlibs.std'
local color = require 'foundation.color'

local Color = color.Color

---@class elxtextstyle
local M = {}

---@alias TextAlign "left" | "center" | "right"

M.Align = {
    LEFT = 'left',
    CENTER = 'center',
    RIGHT = 'right',
}

---@param value any
---@param default any
local function pick(value, default)
    return value == nil and default or value
end

---@class TextStyleOpts
---@field color Color?
---@field font_family string?
---@field bold boolean?
---@field italic boolean?
---@field letter_spacing number? extra px between glyphs
---@field line_height number? multiple of `font_size`
---@field align TextAlign?
---@field wrap boolean?

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
---@overload fun(font_size: number?, options: TextStyleOpts?): TextStyle
local TextStyle = std.class.new('TextStyle')

function TextStyle:__init(font_size, options)
    options = options or {}
    self.font_size = font_size or 16
    self.color = options.color or Color.argb(0xFFFFFFFF)
    self.font_family = options.font_family
    self.bold = options.bold or false
    self.italic = options.italic or false
    self.letter_spacing = options.letter_spacing or 0
    self.line_height = options.line_height or 1.2
    self.align = options.align or M.Align.LEFT
    self.wrap = options.wrap ~= false
end

function TextStyle:__tostring()
    return string.format('TextStyle(%g, %s)', self.font_size, self.font_family or 'default')
end

---@param other TextStyle
---@return boolean
function TextStyle:__eq(other)
    return self.font_size == other.font_size
        and self.color == other.color
        and self.font_family == other.font_family
        and self.bold == other.bold
        and self.italic == other.italic
        and self.letter_spacing == other.letter_spacing
        and self.line_height == other.line_height
        and self.align == other.align
        and self.wrap == other.wrap
end

---@return number
function TextStyle:line_height_px()
    return self.font_size * self.line_height
end

--- Derive a copy with a subset of fields replaced.
---@param options TextStyleOpts
---@return TextStyle
function TextStyle:copy_with(options)
    options = options or {}
    return TextStyle(self.font_size, {
        color = pick(options.color, self.color),
        font_family = pick(options.font_family, self.font_family),
        bold = pick(options.bold, self.bold),
        italic = pick(options.italic, self.italic),
        letter_spacing = pick(options.letter_spacing, self.letter_spacing),
        line_height = pick(options.line_height, self.line_height),
        align = pick(options.align, self.align),
        wrap = pick(options.wrap, self.wrap),
    })
end

M.TextStyle = TextStyle

return M
