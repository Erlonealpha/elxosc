-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- The result of laying a text run out (Flutter's laid out `TextPainter`).
--
-- A Paragraph is the handoff between the text layer and a backend: render
-- objects only deal with its `size`/`lines`, and `Canvas:draw_text` consumes
-- it without ever seeing a raw string.

local std = require 'elxlibs.std'

local M = {}

---@class Paragraph : std.object
---@field text string the original, unwrapped string
---@field style TextStyle
---@field size Size natural logical size after wrapping, before parent constraints
---@field lines string[] the wrapped lines, in visual order
---@field line_height number uniform logical line advance, not an exact ASS baseline distance
---@overload fun(text: string, style: TextStyle, size: Size, lines: string[], line_height: number): self
local Paragraph = std.class.new('Paragraph', {})

function Paragraph:__init(text, style, size, lines, line_height)
    self.text = text
    self.style = style
    self.size = size
    self.lines = lines
    self.line_height = line_height
end

---@return integer
function Paragraph:line_count()
    return #self.lines
end

---@return boolean
function Paragraph:is_empty()
    return #self.lines == 0
end

M.Paragraph = Paragraph

return M
