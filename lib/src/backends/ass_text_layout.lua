-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Native-capable `TextLayout` for the ASS backend.
--
-- Uses an injected ASS measurement capability for natural line spans, with a
-- bounded cache and the character estimate as an explicit offline fallback.

---@namespace elxosc
---@using elxosc

local std = require 'elxlibs.std'
local text_layout = require 'src.text.text_layout'
local ass_text_mod = require 'src.backends.ass_text'

local TextLayout = text_layout.TextLayout

---@class mod.src.backends.ass_text_layout
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

---@alias AssTextMeasureSource 'native' | 'estimate' | 'empty'
---@alias AssTextMeasureReason 'offline' | 'unavailable' | 'error' | 'unreliable' | 'unsupported'

---@class AssTextBounds
---@field x0 number
---@field y0 number
---@field x1 number
---@field y1 number

---@alias AssTextRawBounds AssTextBounds | table<never, never>
---@alias AssTextMeasureErrorKind 'unavailable' | 'error'
---@alias AssTextMeasure sync fun(data: string): AssTextRawBounds?, string?, AssTextMeasureErrorKind?

---@class _AssTextLayoutOptions
---@field measure_ass AssTextMeasure?
---@field res_x number?
---@field res_y number?
---@field default_font_family string?
---@field cache_entries integer? default 512; zero disables caching
---@field cache_bytes integer? default 262144; original text and shape key bytes

---@class AssTextCacheEntry
---@field key string
---@field width number
---@field source AssTextMeasureSource
---@field reason AssTextMeasureReason?
---@field previous AssTextCacheEntry?
---@field next AssTextCacheEntry?

---@class AssTextCacheStats
---@field entries integer
---@field bytes integer
---@field hits integer
---@field native_calls integer
---@field estimates integer
---@field evictions integer

---@class AssTextLayout : TextLayout
---@field private _measure_ass AssTextMeasure?
---@field res_x number immutable measurement environment
---@field res_y number immutable measurement environment
---@field default_font_family string? immutable resolved font environment
---@field private _capacity integer
---@field private _byte_capacity integer
---@field private _cache table<string, AssTextCacheEntry>
---@field private _head AssTextCacheEntry?
---@field private _tail AssTextCacheEntry?
---@field private _stats AssTextCacheStats
---@field private _failure AssTextMeasureReason?
---@overload fun(options?: _AssTextLayoutOptions): self
local AssTextLayout = std.class.new('AssTextLayout', TextLayout)

---@param value number?
---@param default number
---@param name string
---@return integer
local function capacity(value, default, name)
    value = value == nil and default or value
    if type(value) ~= 'number' or value < 0 or value == math.huge
        or value ~= math.floor(value) then
        std.raise(std.ValueError('AssTextLayout.' .. name .. ' must be a non-negative integer'))
    end
    return math.floor(value --[[@as number]])
end

---@param value number
---@return boolean
local function positive_resolution(value)
    return type(value) == 'number' and value >= 1 and value < math.huge
        and value == math.floor(value)
end

function AssTextLayout:__init(options)
    options = options or {}
    if type(options) ~= 'table' then
        std.raise(std.TypeError('AssTextLayout expects an options table'))
    end
    self._measure_ass = options.measure_ass
    self.res_x = options.res_x or 0
    self.res_y = options.res_y or 0
    self.default_font_family = options.default_font_family
    if self.default_font_family ~= nil and (type(self.default_font_family) ~= 'string'
        or self.default_font_family:find('[\r\n%z{}\\]')) then
        std.raise(std.ValueError('AssTextLayout.default_font_family must be a literal font name'))
    end
    if self._measure_ass ~= nil then
        if type(self._measure_ass) ~= 'function' then
            std.raise(std.TypeError('AssTextLayout.measure_ass must be a function'))
        end
        if not positive_resolution(self.res_x) or not positive_resolution(self.res_y) then
            std.raise(std.ValueError('AssTextLayout requires positive finite resolution integers'))
        end
    end
    self._capacity = capacity(options.cache_entries, 512, 'cache_entries')
    self._byte_capacity = capacity(options.cache_bytes, 262144, 'cache_bytes')
    self._cache = {}
    self._head = nil
    self._tail = nil
    self._failure = nil
    self._stats = { entries = 0, bytes = 0, hits = 0, native_calls = 0, estimates = 0, evictions = 0 }
end

-- Inherit the logical line advance. The actual spacing of a multi-line ASS
-- event is controlled by libass; paint transforms do not alter logical metrics.
---@param line string
---@param style TextStyle
---@return number
local function estimate_width(line, style)
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
    return math.max(0, width)
end

---@param entry AssTextCacheEntry
function AssTextLayout:_unlink(entry)
    if entry.previous then
        entry.previous.next = entry.next
    else
        self._head = entry.next
    end
    if entry.next then
        entry.next.previous = entry.previous
    else
        self._tail = entry.previous
    end
end

---@param entry AssTextCacheEntry
function AssTextLayout:_touch(entry)
    entry.previous = nil
    entry.next = self._head
    if self._head then
        self._head.previous = entry
    end
    self._head = entry
    if self._tail == nil then
        self._tail = entry
    end
end

---@param key string
---@param width number
---@param source AssTextMeasureSource
---@param reason AssTextMeasureReason?
function AssTextLayout:_remember(key, width, source, reason)
    if self._capacity == 0 or #key > self._byte_capacity then
        return
    end
    while self._tail and (self._stats.entries >= self._capacity
        or self._stats.bytes + #key > self._byte_capacity) do
        local old = self._tail
        self:_unlink(old)
        self._cache[old.key] = nil
        self._stats.entries = self._stats.entries - 1
        self._stats.bytes = self._stats.bytes - #old.key
        self._stats.evictions = self._stats.evictions + 1
        old.previous = nil
        old.next = nil
    end
    local entry = { key = key, width = width, source = source, reason = reason }
    self._cache[key] = entry
    self:_touch(entry)
    self._stats.entries = self._stats.entries + 1
    self._stats.bytes = self._stats.bytes + #key
end

--- Diagnostic snapshot; it does not expose or retain cache entries.
---@return AssTextCacheStats
function AssTextLayout:cache_stats()
    local stats = self._stats
    return { entries = stats.entries, bytes = stats.bytes, hits = stats.hits,
        native_calls = stats.native_calls, estimates = stats.estimates, evictions = stats.evictions }
end

---@param data string
---@return AssTextBounds?
---@return AssTextMeasureReason?
function AssTextLayout:_bounds(data)
    self._stats.native_calls = self._stats.native_calls + 1
    local measure = self._measure_ass
    if measure == nil then
        return nil, 'offline'
    end
    local ok, raw, measure_error, kind = pcall(measure, data)
    if not ok or raw == nil or measure_error ~= nil then
        self._failure = ok and kind == 'unavailable' and 'unavailable' or 'error'
        return nil, self._failure
    end
    if type(raw) ~= 'table' then
        self._failure = 'error'
        return nil, self._failure
    end
    for _, name in ipairs({ 'x0', 'x1', 'y0', 'y1' }) do
        local value = raw[name]
        if type(value) ~= 'number' or value ~= value or value == math.huge or value == -math.huge then
            return nil, 'unreliable'
        end
    end
    if raw.x0 <= 0 or raw.y0 <= 0 or raw.x1 >= self.res_x or raw.y1 >= self.res_y
        or raw.x1 <= raw.x0 or raw.y1 <= raw.y0 then
        return nil, 'unreliable'
    end
    return raw --[[@as AssTextBounds]]
end

---@param line string
---@param style TextStyle
---@return number?
---@return AssTextMeasureReason?
function AssTextLayout:_native_width(line, style)
    local left_x = 32
    local right_x = math.floor(self.res_x) - 32
    if right_x <= left_x then
        return nil, 'unreliable'
    end
    local y = math.floor(self.res_y / 2)
    local shape = ass_text_mod.shape_tags(style, self.default_font_family)
    local text = ass_text_mod.escape_line(line)
    local function event(anchor, x)
        return string.format('{\\pos(%d,%d)\\rDefault\\an%d\\blur0%s\\bord0\\shad0\\1a&H00&}%s',
            x, y, anchor, shape, text)
    end
    local left, reason = self:_bounds(event(4, left_x))
    if not left then
        return nil, reason
    end
    local right, right_reason = self:_bounds(event(6, right_x))
    if not right then
        return nil, right_reason
    end
    local distance = right_x - left_x
    local d0 = left.x0 - right.x0 + distance
    local d1 = left.x1 - right.x1 + distance
    local width = (d0 + d1) / 2
    if width < 0 or math.abs(d0 - d1) > 2 then
        return nil, 'unreliable'
    end
    return width
end

--- Original text is never changed. The width is a positioning span, not ink or
--- baseline metrics. Native failure latches until the host replaces this layout.
---@param line string
---@param style TextStyle
---@return number width
---@return AssTextMeasureSource source
---@return AssTextMeasureReason? reason
function AssTextLayout:measure_line(line, style)
    if line == '' or style.font_size == 0 then
        return 0, 'empty'
    end
    local family = style.font_family or self.default_font_family or ''
    local key = string.format('%d:%s:%.17g:%s:%s:%.17g:%s', #family, family,
        style.font_size, tostring(style.bold), tostring(style.italic), style.letter_spacing, line)
    local cached = self._cache[key]
    if cached then
        self:_unlink(cached)
        self:_touch(cached)
        self._stats.hits = self._stats.hits + 1
        return cached.width, cached.source, cached.reason
    end
    local width
    local reason = self._failure
    if not self._measure_ass then
        reason = 'offline'
    elseif not reason then
        if line:find('[\r\n\t\v\f%z]') or line:find('\226\128[\128-\138]')
            or line:find('\227\128\128') or line:find('\226\128[\168\169\175]')
            or line:find('\226\129\159') or line:find('\194\133') or line:find('\225\154\128') then
            reason = 'unsupported'
        elseif line:gsub(' ', ''):gsub('\194\160', '') == '' then
            local marked, marked_reason = self:_native_width(line .. '|', style)
            if marked then
                local marker, marker_source, marker_reason = self:measure_line('|', style)
                if marker_source == 'native' and marked >= marker then
                    width = marked - marker
                else
                    reason = marker_reason or 'unreliable'
                end
            else
                reason = marked_reason
            end
        else
            width, reason = self:_native_width(line, style)
        end
    end
    local source = width ~= nil and 'native' or 'estimate'
    if width == nil then
        width = estimate_width(line, style)
        self._stats.estimates = self._stats.estimates + 1
    end
    self:_remember(key, width, source, reason)
    return width, source, reason
end

function AssTextLayout:line_width(line, style)
    local width = self:measure_line(line, style)
    return width
end

M.AssTextLayout = AssTextLayout

return M
