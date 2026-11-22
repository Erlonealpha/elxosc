-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- The result of laying a text run out (Flutter's laid out `TextPainter`).
--
-- A Paragraph is the handoff between the text layer and a backend: render
-- objects only deal with its `size`/`lines`, and `Canvas:draw_text` consumes
-- it without ever seeing a raw string.

---@namespace elxosc
---@using elxosc

local dataclass = require 'elxlibs.dataclass'

---@class mod.src.text.paragraph
local M = {}

---@alias TextMeasureSource 'native' | 'estimate' | 'empty' | 'backend'
---@class TextLineMetrics
---@field width number
---@field start_byte integer one-based UTF-8 byte offset
---@field end_byte integer exclusive original byte offset, excluding hard breaks
---@field source TextMeasureSource
---@field reason string?
---@field truncated boolean

---@class _ParagraphOptions
---@field line_metrics TextLineMetrics[]?
---@field max_width number?
---@field overflow TextOverflow?
---@field truncated boolean?

---@class Paragraph : dataclass.Object
---@field text string the original, unwrapped string
---@field style TextStyle
---@field size Size natural logical size after wrapping, before parent constraints
---@field lines string[] the wrapped lines, in visual order
---@field line_height number uniform logical line advance, not an exact ASS baseline distance
---@field line_metrics TextLineMetrics[]
---@field max_width number
---@field overflow TextOverflow
---@field truncated boolean
---@overload fun(text: string, style: TextStyle, size: Size, lines: string[], line_height: number, options?: _ParagraphOptions): self
local Paragraph = dataclass.new('Paragraph', nil, { eq = false, repr = false })({
    dataclass.field('text', nil),
    dataclass.field('style', nil),
    dataclass.field('size', nil),
    dataclass.field('lines', nil),
    dataclass.field('line_height', nil),
    dataclass.field('line_metrics', nil),
    dataclass.field('max_width', math.huge),
    dataclass.field('overflow', nil),
    dataclass.field('truncated', false),
})

function Paragraph:__init(text, style, size, lines, line_height, options)
    options = options or {}
    self.text = text
    self.style = style
    self.size = size
    self.lines = {}
    self.line_metrics = {}
    for index, line in ipairs(lines) do
        self.lines[index] = line
        local metric = options.line_metrics and options.line_metrics[index]
        if metric then
            self.line_metrics[index] = { width = metric.width, start_byte = metric.start_byte,
                end_byte = metric.end_byte, source = metric.source, reason = metric.reason,
                truncated = metric.truncated }
        end
    end
    self.line_height = line_height
    self.max_width = options.max_width or math.huge
    self.overflow = options.overflow or style.overflow
    self.truncated = options.truncated == true
end

--- Preserve the prepared line results while replacing only paint style.
---@param style TextStyle
---@return Paragraph
function Paragraph:with_style(style)
    return Paragraph(self.text, style, self.size, self.lines, self.line_height, {
        line_metrics = self.line_metrics, max_width = self.max_width,
        overflow = self.overflow, truncated = self.truncated,
    })
end

---@return integer
function Paragraph:line_count()
    return #self.lines
end

---@return boolean
function Paragraph:is_empty()
    return #self.lines == 0
end

dataclass.finish(Paragraph)

M.Paragraph = Paragraph

return M
