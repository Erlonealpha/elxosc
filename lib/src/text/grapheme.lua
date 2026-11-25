-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha
-- Finite UTF-8 cluster rules for text wrapping, not a complete Unicode segmenter.
---@namespace elxosc
---@using elxosc

local std = require 'elxlibs.std'

---@class TextCluster
---@field text           string
---@field start_byte     integer
---@field end_byte       integer exclusive
---@field codepoint      integer first codepoint
---@field last_codepoint integer

---@class mod.src.text.grapheme
local M = {}

---@param text  string
---@param index integer
---@return integer codepoint
---@return integer next_byte
local function decode(text, index)
    local lead = text:byte(index)
    if lead < 128 then
        return lead, index + 1
    end
    local length = lead >= 0xC2 and lead <= 0xDF and 2 or lead >= 0xE0 and lead <= 0xEF and 3
        or lead >= 0xF0 and lead <= 0xF4 and 4 or 0
    local value = length == 2 and lead - 0xC0 or length == 3 and lead - 0xE0 or lead - 0xF0
    for offset = 1, length - 1 do
        local byte = text:byte(index + offset)
        if byte == nil or byte < 0x80 or byte > 0xBF then
            length = 0
            break
        end
        value = value * 64 + byte - 0x80
    end
    if length == 0 or (length == 3 and value < 0x800) or (length == 4 and value < 0x10000) or value > 0x10FFFF
        or value >= 0xD800 and value <= 0xDFFF then
        std.raise(std.ValueError('TextLayout requires valid UTF-8 at byte ' .. index))
    end
    return value, index + length
end

---@param value integer
---@return boolean
local function extend(value)
    return value >= 0x0300 and value <= 0x036F or value >= 0x0483 and value <= 0x0489
        or value >= 0x0591 and value <= 0x05BD or value == 0x05BF
        or value >= 0x05C1 and value <= 0x05C2 or value >= 0x05C4 and value <= 0x05C5
        or value >= 0x0610 and value <= 0x061A or value >= 0x064B and value <= 0x065F
        or value == 0x0670 or value >= 0x06D6 and value <= 0x06ED
        or value >= 0x1AB0 and value <= 0x1AFF or value >= 0x1DC0 and value <= 0x1DFF
        or value >= 0x20D0 and value <= 0x20FF or value >= 0xFE00 and value <= 0xFE0F
        or value >= 0xFE20 and value <= 0xFE2F or value >= 0x1F3FB and value <= 0x1F3FF
        or value >= 0xE0100 and value <= 0xE01EF or value >= 0xE0020 and value <= 0xE007F
end

---@param value integer
---@return string?
local function hangul(value)
    if value >= 0x1100 and value <= 0x115F or value >= 0xA960 and value <= 0xA97C then
        return 'L'
    elseif value >= 0x1160 and value <= 0x11A7 or value >= 0xD7B0 and value <= 0xD7C6 then
        return 'V'
    elseif value >= 0x11A8 and value <= 0x11FF or value >= 0xD7CB and value <= 0xD7FB then
        return 'T'
    elseif value >= 0xAC00 and value <= 0xD7A3 then
        return (value - 0xAC00) % 28 == 0 and 'LV' or 'LVT'
    end
end

---@param value integer
---@return boolean
function M.is_cjk(value)
    return value >= 0x2E80 and value <= 0x9FFF or value >= 0xAC00 and value <= 0xD7A3
        or value >= 0xF900 and value <= 0xFAFF or value >= 0x20000 and value <= 0x323AF
end

--- Validate the full source even when a visible-line limit stops layout early.
---@param text string
function M.validate_utf8(text)
    local index = 1
    while index <= #text do
        local _, next_byte = decode(text, index)
        index = next_byte
    end
end

--- Byte ranges are one-based and half-open; a tab's rendered text is four spaces.
---@param text       string
---@param start_byte integer? original-text start offset; default 1
---@return TextCluster[]
function M.clusters(text, start_byte)
    local clusters = {}
    local index = 1
    local offset = (start_byte or 1) - 1
    local regional_count = 0
    local previous
    while index <= #text do
        local codepoint, next_byte = decode(text, index)
        local last = clusters[#clusters]
        local regional = codepoint >= 0x1F1E6 and codepoint <= 0x1F1FF
        local current_hangul = hangul(codepoint)
        local previous_hangul = previous and hangul(previous)
        local joins_hangul = previous_hangul == 'L'
            and (current_hangul == 'L' or current_hangul == 'V' or current_hangul == 'LV' or current_hangul == 'LVT') or (previous_hangul
            == 'LV'
            or previous_hangul == 'V')
            and (current_hangul == 'V' or current_hangul == 'T')
            or (previous_hangul == 'LVT' or previous_hangul == 'T') and current_hangul == 'T'
        local joins = last
            and (extend(codepoint) or codepoint == 0x200D
                or previous == 0x200D or regional and regional_count % 2 == 1
                or joins_hangul)
        local part = codepoint == 9 and '    ' or text:sub(index, next_byte - 1)
        if joins and previous ~= 9 and codepoint ~= 9 then
            last.text = last.text .. part
            last.end_byte = next_byte + offset
            last.last_codepoint = codepoint
        else
            clusters[#clusters + 1] = {
                text = part,
                start_byte = index + offset,
                end_byte = next_byte + offset,
                codepoint = codepoint,
                last_codepoint = codepoint
            }
        end
        regional_count = regional and regional_count + 1 or 0
        previous = codepoint
        index = next_byte
    end
    return clusters
end

return M
