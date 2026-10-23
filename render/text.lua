-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Leaf that lays out and paints a run of text (Flutter's `RenderParagraph`).
--
-- Measurement is delegated to a `TextLayout` (the engine stand-in), so the
-- render tree stays free of any font/backend assumption.

local std = require 'elxlibs.std'
local geometry = require 'foundation.geometry'
local anchor_mod = require 'foundation.anchor'
local text_paint_mod = require 'painting.text_paint'
local text_style = require 'text.text_style'
local render_object = require 'render.render_object'
local text_layout = require 'text.text_layout'

local Offset = geometry.Offset
local Anchor = anchor_mod.Anchor
local RenderObject = render_object.RenderObject
local Align = text_style.Align
local raise = std.raise

local M = {}

---@class RenderText : RenderObject
---@field text string
---@field style TextStyle
---@field text_layout TextLayout?
---@field paragraph Paragraph?
---@field text_paint TextPaint
---@overload fun(text: string, style: TextStyle, text_layout: TextLayout?, text_paint: TextPaint?): self
local RenderText = std.class.new('RenderText', { RenderObject })

---@param text string
---@param style TextStyle
---@param measurer TextLayout?
---@param text_paint TextPaint?
function RenderText:__init(text, style, measurer, text_paint)
    std.super(RenderText, self, RenderObject).__init(self)
    self.text = text
    self.style = style
    self.text_layout = measurer
    self.text_paint = text_paint_mod.resolve(text_paint)
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
    -- RenderObject:layout constrains our box. Keep the paragraph's natural
    -- logical size intact; neither size promises exact backend ink bounds.
    self.size = paragraph.size
end

---@param canvas PaintingContext
function RenderText:__paint(canvas, offset)
    if self.paragraph then
        -- Anchor within the constrained layout box, not the estimated natural
        -- paragraph. In particular a ligature name may measure much wider than
        -- the icon box while its native glyph still belongs at the box center.
        local anchor = self.text_paint.anchor
        if not self.text_paint._anchor_explicit then
            if self.style.align == Align.CENTER then
                anchor = Anchor.CENTER
            elseif self.style.align == Align.RIGHT then
                anchor = Anchor.CENTER_RIGHT
            else
                anchor = Anchor.CENTER_LEFT
            end
        end
        local fraction = anchor_mod.fraction(anchor)
        local position = (offset + Offset(
            self.size.width * fraction.x,
            self.size.height * fraction.y)) --[[@as Offset]]
        local text_paint = self.text_paint
        if anchor ~= self.text_paint.anchor then
            text_paint = self.text_paint:copy_with({ anchor = anchor })
        end
        canvas:draw_text(self.paragraph, position, text_paint)
    end
    self:paint_children(canvas, offset)
end

M.RenderText = RenderText

return M
