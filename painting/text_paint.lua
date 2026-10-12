-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Backend-neutral text painting parameters, immutable by convention. `anchor`
-- selects the content reference point; the backend positions it at the target
-- supplied to Canvas:draw_text plus `offset`, before applying Canvas transforms.

local std = require 'elxlibs.std'
local geometry = require 'foundation.geometry'
local anchor_mod = require 'foundation.anchor'

local Offset = geometry.Offset
local Anchor = anchor_mod.Anchor
local raise = std.raise
local rawget = rawget

local M = {}

---@class _TextPaintOptions
---@field anchor? AnchorName defaults to top_left
---@field offset? Offset finite logical-pixel visual offset; does not affect layout or hit testing

---@class TextPaint : std.object
---@field anchor AnchorName
---@field offset Offset
---@field _anchor_explicit boolean
---@overload fun(options?: _TextPaintOptions): self
local TextPaint = std.class.new('TextPaint', {})

local option_names = {
    anchor = true,
    offset = true,
}

---@param options _TextPaintOptions?
---@return _TextPaintOptions
local function check_options(options)
    if options == nil then
        return {}
    end
    if type(options) ~= 'table' then
        raise(std.TypeError('TextPaint expects an options table'))
    end
    for name in pairs(options) do
        if not option_names[name] then
            raise(std.ValueError('unsupported TextPaint option: ' .. tostring(name)))
        end
    end
    return options
end

---@param value any
---@return boolean
local function is_offset(value)
    return type(value) == 'table' and rawequal(rawget(value, '__class'), Offset)
end

---@param name string
---@param value any
---@return number
local function check_finite(name, value)
    if type(value) ~= 'number' or value ~= value
        or value == math.huge or value == -math.huge then
        raise(std.ValueError('TextPaint.' .. name .. ' must be a finite number'))
    end
    return value
end

---@param value any
---@return Offset
local function check_offset(value)
    if not is_offset(value) then
        raise(std.TypeError('TextPaint.offset must be an Offset'))
    end
    check_finite('offset.x', value.x)
    check_finite('offset.y', value.y)
    return value
end

--- Resolve an optional paint value at the widget/render/backend boundary.
---@param value TextPaint?
---@return TextPaint
function M.resolve(value)
    if value == nil then
        return TextPaint()
    end
    if type(value) ~= 'table' or not rawequal(rawget(value, '__class'), TextPaint) then
        raise(std.TypeError('text_paint must be a TextPaint'))
    end
    return value
end

---@param options? _TextPaintOptions
function TextPaint:__init(options)
    options = check_options(options)
    self._anchor_explicit = options.anchor ~= nil
    self.anchor = options.anchor == nil and Anchor.TOP_LEFT or options.anchor
    self.offset = options.offset == nil and Offset.zero() or options.offset
    if not anchor_mod.is_valid(self.anchor) then
        raise(std.ValueError('TextPaint.anchor is not a valid nine-point anchor'))
    end
    check_offset(self.offset)
end

---@param options? _TextPaintOptions
---@return TextPaint
function TextPaint:copy_with(options)
    options = check_options(options)
    local copy = TextPaint({
        anchor = options.anchor == nil and self.anchor or options.anchor,
        offset = options.offset == nil and self.offset or options.offset,
    })
    copy._anchor_explicit = self._anchor_explicit or options.anchor ~= nil
    return copy
end

---@param other TextPaint
---@return boolean
function TextPaint:__eq(other)
    return self.anchor == other.anchor and self.offset == other.offset
        and self._anchor_explicit == other._anchor_explicit
end

M.TextPaint = TextPaint

return M
