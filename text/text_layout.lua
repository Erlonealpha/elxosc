-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Text measurement contract + generic wrapping.
--
-- `line_width` requires a backend; `line_height` has a logical default which a
-- backend may override. ASS estimates; a native backend can use font metrics.
-- Everything else -- hard line breaks, greedy word wrapping, the paragraph
-- box -- is generic and therefore implemented once, here.

local std = require 'elxlibs.std'
local geometry = require 'foundation.geometry'
local paragraph = require 'text.paragraph'

local Size = geometry.Size
local Paragraph = paragraph.Paragraph
local raise = std.raise
local math = math
local max = math.max

local M = {}

-- The engine stand-in: a single ambient measurer, like the engine's paragraph
-- builder in Flutter. Hosts install one (`AssTextLayout` in mpv); widgets that
-- need text measurement fall back to it.
---@type TextLayout?
local default_layout = nil

---@param layout TextLayout?
function M.set_default(layout)
    default_layout = layout
end

---@return TextLayout?
function M.get_default()
    return default_layout
end

---@param text string
---@return string[]
local function split_hard_lines(text)
    local lines = {}
    for line in (text .. '\n'):gmatch('([^\n]*)\n') do
        lines[#lines + 1] = line
    end
    return lines
end

--- Greedy word wrap of one hard line. Words longer than the bound are left on
--- their own (over-long) line rather than broken mid-word.
---@param line string
---@param max_width number
---@param width_of fun(candidate: string): number
---@return string[]
local function wrap_line(line, max_width, width_of)
    if line == '' or max_width == math.huge then
        return { line }
    end
    local words = {}
    for word in line:gmatch('%S+') do
        words[#words + 1] = word
    end
    if #words <= 1 then
        return { line }
    end
    local out = {}
    local current = words[1]
    for i = 2, #words do
        local candidate = current .. ' ' .. words[i]
        if width_of(candidate) <= max_width then
            current = candidate
        else
            out[#out + 1] = current
            current = words[i]
        end
    end
    out[#out + 1] = current
    return out
end

---@class TextLayout : std.object
---@overload fun(): self
local TextLayout = std.class.new('TextLayout', {})

--- Uniform logical line advance for a paragraph, not a glyph ink height.
---@param style TextStyle
---@return number
function TextLayout:line_height(style)
    return style:line_height_px()
end

--- Abstract: natural width of one already wrapped line, in logical pixels.
---@param line string
---@param style TextStyle
---@return number
function TextLayout:line_width(line, style)
    raise(std.NotImplementedError('TextLayout:line_width must be implemented by a text backend'))
end

--- Wrap `text` and produce a Paragraph. `max_width` is unbounded when nil.
---@param text string
---@param style TextStyle
---@param max_width number? unbounded when nil / math.huge
---@return Paragraph
function TextLayout:layout(text, style, max_width)
    local line_height = self:line_height(style)
    if type(line_height) ~= 'number' or line_height ~= line_height
        or line_height < 0 or line_height == math.huge then
        raise(std.ValueError('TextLayout:line_height must return a non-negative finite number'))
    end
    local bounds = max_width or math.huge
    local lines = {}
    if #text > 0 then
        for _, hard in ipairs(split_hard_lines(text)) do
            if style.wrap then
                local wrapped = wrap_line(hard, bounds, function(candidate)
                    return self:line_width(candidate, style)
                end)
                for _, line in ipairs(wrapped) do
                    lines[#lines + 1] = line
                end
            else
                lines[#lines + 1] = hard
            end
        end
    end
    local width = 0
    for _, line in ipairs(lines) do
        width = max(width, self:line_width(line, style))
    end
    return Paragraph(text, style, Size(width, #lines * line_height), lines, line_height)
end

M.TextLayout = TextLayout

return M
