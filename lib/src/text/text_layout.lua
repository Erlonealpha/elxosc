-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Text measurement contract + generic wrapping.
--
-- `line_width` requires a backend; `line_height` has a logical default which a
-- backend may override. ASS uses injected native spans or explicit offline estimates.
-- Everything else -- hard line breaks, greedy word wrapping, the paragraph
-- box -- is generic and therefore implemented once, here.

---@namespace elxosc
---@using elxosc

local std = require 'elxlibs.std'
local geometry = require 'src.foundation.geometry'
local paragraph = require 'src.text.paragraph'
local grapheme_mod = require 'src.text.grapheme'

local Size = geometry.Size
local Paragraph = paragraph.Paragraph
local raise = std.raise
local math = math
local max = math.max

---@class mod.src.text.text_layout
local M = {}

-- Offline fallback for manual render trees. Production Widgets resolve their
-- TextLayoutScope first; host-owned native resources never belong here.
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

---@class TextHardLine
---@field text string
---@field start_byte integer
---@field end_byte integer

---@param text string
---@return TextHardLine[]
local function split_hard_lines(text)
    local lines = {}
    local start = 1
    local index = 1
    while index <= #text do
        local byte = text:byte(index)
        if byte == 10 or byte == 13 then
            lines[#lines + 1] = { text = text:sub(start, index - 1), start_byte = start, end_byte = index }
            if byte == 13 and text:byte(index + 1) == 10 then
                index = index + 1
            end
            start = index + 1
        end
        index = index + 1
    end
    lines[#lines + 1] = { text = text:sub(start), start_byte = start, end_byte = #text + 1 }
    return lines
end

---@param cluster TextCluster
---@return boolean
local function whitespace(cluster)
    return cluster.codepoint == 32 or cluster.codepoint == 9
end

---@class TextLayout : std.object
---@overload fun(): self
local TextLayout = std.class.new('TextLayout')

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

--- Backends may override to retain measurement provenance without changing layout.
---@param line string
---@param style TextStyle
---@return number
---@return TextMeasureSource
---@return string?
function TextLayout:measure_line(line, style)
    return self:line_width(line, style), line == '' and 'empty' or 'backend'
end

--- Wrap `text` and produce a Paragraph. `max_width` is unbounded when nil.
---@param text string
---@param style TextStyle
---@param max_width number? unbounded when nil / math.huge
---@return Paragraph
function TextLayout:layout(text, style, max_width)
    grapheme_mod.validate_utf8(text)
    local line_height = self:line_height(style)
    if type(line_height) ~= 'number' or line_height ~= line_height
        or line_height < 0 or line_height == math.huge then
        raise(std.ValueError('TextLayout:line_height must return a non-negative finite number'))
    end
    local bounds = max_width == nil and math.huge or max_width
    if type(bounds) ~= 'number' or bounds ~= bounds or bounds < 0 then
        raise(std.ValueError('TextLayout.max_width must be non-negative'))
    end
    local lines = {}
    local metrics = {}
    ---@type TextCluster[][]
    local line_clusters = {}
    local function measure(line)
        local width, source, reason = self:measure_line(line, style)
        if type(width) ~= 'number' or width < 0 or width ~= width or width == math.huge then
            raise(std.ValueError('TextLayout:line_width must return a finite non-negative width'))
        end
        return width, source, reason
    end
    local function append(clusters, first, last, start_byte, end_byte)
        local parts = {}
        for index = first, last do
            parts[#parts + 1] = clusters[index].text
        end
        local line = table.concat(parts)
        local width, source, reason = measure(line)
        lines[#lines + 1] = line
        local selected = {}
        for index = first, last do
            selected[#selected + 1] = clusters[index]
        end
        line_clusters[#line_clusters + 1] = selected
        metrics[#metrics + 1] = { width = width, source = source, reason = reason,
            start_byte = start_byte, end_byte = end_byte, truncated = false }
    end
    if #text > 0 then
        for _, hard in ipairs(split_hard_lines(text)) do
            local clusters = grapheme_mod.clusters(hard.text, hard.start_byte)
            if not style.wrap or bounds == math.huge or #clusters == 0 then
                append(clusters, 1, #clusters, hard.start_byte, hard.end_byte)
            else
                local first = 1
                local overlong_end = 0
                while first <= #clusters do
                    local parts = {}
                    local last_fit = first - 1
                    local index = first
                    -- Measure whole word/CJK candidates first. Only an overlong
                    -- first unit needs cluster-by-cluster splitting.
                    while first > overlong_end and index <= #clusters do
                        local cluster = assert(clusters[index])
                        parts[#parts + 1] = cluster.text
                        local next_cluster = clusters[index + 1]
                        local can_break = next_cluster == nil
                        if next_cluster and (whitespace(cluster) and not whitespace(next_cluster)
                            or grapheme_mod.is_cjk(cluster.last_codepoint)
                            or grapheme_mod.is_cjk(next_cluster.codepoint)) then
                            can_break = true
                        end
                        if can_break then
                            local width = measure(table.concat(parts))
                            if width > bounds then
                                if last_fit < first then
                                    overlong_end = index
                                end
                                break
                            end
                            last_fit = index
                        end
                        index = index + 1
                    end
                    if last_fit < first then
                        parts = {}
                        for split = first, max(index, overlong_end) do
                            local cluster = clusters[split]
                            if cluster == nil then
                                break
                            end
                            parts[#parts + 1] = cluster.text
                            if measure(table.concat(parts)) > bounds then
                                break
                            end
                            last_fit = split
                        end
                    end
                    local last = max(first, last_fit)
                    append(clusters, first, last, assert(clusters[first]).start_byte, assert(clusters[last]).end_byte)
                    first = last + 1
                    if style.max_lines and #lines > style.max_lines then
                        break
                    end
                end
            end
            if style.max_lines and #lines > style.max_lines then
                break
            end
        end
    end
    local truncated = style.max_lines ~= nil and #lines > style.max_lines
    local line_limit_truncated = truncated
    if truncated then
        for index = #lines, assert(style.max_lines) + 1, -1 do
            lines[index] = nil
            metrics[index] = nil
            line_clusters[index] = nil
        end
        metrics[#metrics].truncated = true
    end
    if style.overflow == 'ellipsis' then
        for index, line in ipairs(lines) do
            if metrics[index].width > bounds or line_limit_truncated and index == #lines then
                local metric = metrics[index]
                local clusters = assert(line_clusters[index])
                local visible = ''
                local end_byte = metric.start_byte
                if measure('…') <= bounds then
                    visible = '…'
                    local prefix = ''
                    for _, cluster in ipairs(clusters) do
                        prefix = prefix .. cluster.text
                        -- Shaping and negative spacing need not be monotonic.
                        -- Keep the longest supported prefix that actually fits.
                        if measure(prefix .. '…') <= bounds then
                            visible = prefix .. '…'
                            end_byte = cluster.end_byte
                        end
                    end
                end
                lines[index] = visible
                metric.width, metric.source, metric.reason = measure(visible)
                metric.end_byte = math.min(metric.end_byte, end_byte)
                metric.truncated = true
                truncated = true
            end
        end
    end
    local width = 0
    for _, metric in ipairs(metrics) do
        width = max(width, metric.width)
    end
    local height = #lines * line_height
    if height == math.huge then
        raise(std.ValueError('TextLayout paragraph height must be finite'))
    end
    return Paragraph(text, style, Size(width, height), lines, line_height, {
        line_metrics = metrics, max_width = bounds, overflow = style.overflow, truncated = truncated,
    })
end

M.TextLayout = TextLayout

return M
