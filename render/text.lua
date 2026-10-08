-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Leaf that lays out and paints a run of text (Flutter's `RenderParagraph`).
--
-- Measurement is delegated to a `TextLayout` (the engine stand-in), so the
-- render tree stays free of any font/backend assumption.

local std = require 'elxlibs.std'
local render_object = require 'render.render_object'
local text_layout = require 'text.text_layout'

local RenderObject = render_object.RenderObject
local raise = std.raise

---@class elxtext
local M = {}

---@class RenderText : RenderObject
---@field text string
---@field style TextStyle
---@field text_layout TextLayout?
---@field paragraph Paragraph?
---@overload fun(text: string, style: TextStyle, text_layout: TextLayout?): RenderText
local RenderText = std.class.new('RenderText', { RenderObject })

function RenderText:__init(text, style, measurer)
    std.super(RenderText, self, RenderObject).__init(self)
    self.text = text
    self.style = style
    self.text_layout = measurer
    self.paragraph = nil
end

---@return TextLayout
function RenderText:measurer()
    local layout = self.text_layout or text_layout.get_default()
    if not layout then
        raise(std.RuntimeError(
            'RenderText needs a TextLayout: pass one or call text_layout.set_default()'))
    end
    return layout
end

function RenderText:__perform_layout(constraints)
    local bounds = constraints:has_bounded_width() and constraints.max_width or math.huge
    local paragraph = self:measurer():layout(self.text, self.style, bounds)
    self.paragraph = paragraph
    self.size = paragraph.size
end

function RenderText:__paint(canvas, offset)
    if self.paragraph then
        canvas:draw_text(self.paragraph, offset)
    end
    self:paint_children(canvas, offset)
end

M.RenderText = RenderText

return M
