-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Estimating `TextLayout` for the ASS backend.
--
-- ASS gives us no way to measure text, so this approximates a line's width
-- from its characters: half an em per narrow (Latin) glyph, a full em per wide
-- (CJK/full width) glyph, plus letter spacing. A mpv.net backend can replace it
-- with real font metrics without touching anything else.

local std = require 'elxlibs.std'
local text_layout = require 'text.text_layout'

local TextLayout = text_layout.TextLayout

local M = {}

---@param codepoint integer
---@return number em fraction
local function glyph_ratio(codepoint)
    if codepoint <= 0x7F then
        return 0.5
    end
    -- Rough "East Asian wide" ranges (CJK, Hangul, full-width forms, ...).
    if (codepoint >= 0x1100 and codepoint <= 0x115F)
        or (codepoint >= 0x2E80 and codepoint <= 0xA4CF)
        or (codepoint >= 0xAC00 and codepoint <= 0xD7A3)
        or (codepoint >= 0xF900 and codepoint <= 0xFAFF)
        or (codepoint >= 0xFE30 and codepoint <= 0xFE4F)
        or (codepoint >= 0xFF00 and codepoint <= 0xFF60)
        or (codepoint >= 0xFFE0 and codepoint <= 0xFFE6)
        or codepoint >= 0x20000 then
        return 1.0
    end
    return 0.5
end

---@param byte integer
---@return integer? sequence length, or nil for an invalid lead byte
local function utf8_sequence(byte)
    if byte < 0x80 then
        return 1
    elseif byte < 0xE0 then
        return 2
    elseif byte < 0xF0 then
        return 3
    elseif byte < 0xF8 then
        return 4
    end
    return nil
end

--- Decode the codepoint starting at byte `i`; returns the codepoint and the
--- next byte index. Malformed bytes are yielded as U+FFFD and stepped by one.
---@param s string
---@param i integer
---@return integer codepoint
---@return integer next_index
local function utf8_next(s, i)
    local b1 = s:byte(i)
    if b1 == nil then
        return 0x3F, i + 1
    end
    local seq = utf8_sequence(b1)
    if seq == nil then
        return 0xFFFD, i + 1
    elseif seq == 1 then
        return b1, i + 1
    end
    local b2 = s:byte(i + 1) or 0x80
    if seq == 2 then
        return (b1 % 0x20) * 0x40 + (b2 % 0x40), i + 2
    end
    local b3 = s:byte(i + 2) or 0x80
    if seq == 3 then
        return (b1 % 0x10) * 0x1000 + (b2 % 0x40) * 0x40 + (b3 % 0x40), i + 3
    end
    local b4 = s:byte(i + 3) or 0x80
    return (b1 % 0x08) * 0x40000 + (b2 % 0x40) * 0x1000
        + (b3 % 0x40) * 0x40 + (b4 % 0x40), i + 4
end

---@class AssTextLayout : TextLayout
---@overload fun(): AssTextLayout
local AssTextLayout = std.class.new('AssTextLayout', { TextLayout })

-- Inherit the logical line advance. The actual spacing of a multi-line ASS
-- event is controlled by libass; paint transforms do not alter logical metrics.
function AssTextLayout:line_width(line, style)
    local width = 0
    local count = 0
    local i = 1
    local len = #line
    while i <= len do
        local codepoint, next_i = utf8_next(line, i)
        width = width + glyph_ratio(codepoint) * style.font_size
        count = count + 1
        i = next_i
    end
    if count > 1 then
        width = width + style.letter_spacing * (count - 1)
    end
    return width
end

M.AssTextLayout = AssTextLayout

return M
