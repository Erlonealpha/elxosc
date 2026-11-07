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
local paragraph_mod = require 'text.paragraph'
local color_mod = require 'foundation.color'

local Offset = geometry.Offset
local Anchor = anchor_mod.Anchor
local RenderObject = render_object.RenderObject
local Align = text_style.Align
local Paragraph = paragraph_mod.Paragraph
local Color = color_mod.Color
local raise = std.raise

local M = {}

---@class RenderText : RenderObject
---@field text string
---@field style TextStyle
---@field text_layout TextLayout?
---@field paragraph Paragraph?
---@field text_paint TextPaint
---@field color_override Color?
---@field shadow_color_override Color?
---@field shadow_radius_override number?
---@field glow_color_override Color?
---@field glow_radius_override number?
---@overload fun(text: string, style: TextStyle, text_layout: TextLayout?, text_paint: TextPaint?): self
local RenderText = std.class.new('RenderText', RenderObject)

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
    self.color_override = nil
    self.shadow_color_override = nil
    self.shadow_radius_override = nil
    self.glow_color_override = nil
    self.glow_radius_override = nil
    self.paragraph = nil
end

---@param color Color?
function RenderText:set_color_override(color)
    if color ~= nil and not std.isinstance(color, Color) then
        raise(std.TypeError('RenderText.color_override must be a Color'))
    end
    if self.color_override == color then
        return
    end
    self.color_override = color
    self:mark_needs_paint()
end

---@param color Color?
---@param radius number?
function RenderText:set_shadow_override(color, radius)
    if color ~= nil and not std.isinstance(color, Color) then
        raise(std.TypeError('RenderText.shadow_color_override must be a Color'))
    end
    if radius ~= nil and (type(radius) ~= 'number' or radius < 0
        or radius ~= radius or radius == math.huge or radius == -math.huge) then
        raise(std.ValueError('RenderText.shadow_radius_override must be non-negative and finite'))
    end
    if self.shadow_color_override == color and self.shadow_radius_override == radius then
        return
    end
    self.shadow_color_override = color
    self.shadow_radius_override = radius
    self:mark_needs_paint()
end

---@param color Color?
---@param radius number?
function RenderText:set_glow_override(color, radius)
    if color ~= nil and not std.isinstance(color, Color) then
        raise(std.TypeError('RenderText.glow_color_override must be a Color'))
    end
    if radius ~= nil and (type(radius) ~= 'number' or radius < 0
        or radius ~= radius or radius == math.huge or radius == -math.huge) then
        raise(std.ValueError('RenderText.glow_radius_override must be non-negative and finite'))
    end
    if self.glow_color_override == color and self.glow_radius_override == radius then
        return
    end
    self.glow_color_override = color
    self.glow_radius_override = radius
    self:mark_needs_paint()
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
        local paragraph = self.paragraph
        if self.color_override ~= nil
            or self.shadow_color_override ~= nil then
            local style_options = {}
            if self.color_override ~= nil and paragraph.style.color ~= self.color_override then
                style_options.color = self.color_override
            end
            if self.shadow_color_override ~= nil then
                style_options.shadow_color = self.shadow_color_override
                style_options.shadow_radius = self.shadow_radius_override or 0
            end
            paragraph = Paragraph(
                paragraph.text,
                paragraph.style:copy_with(style_options),
                paragraph.size,
                paragraph.lines,
                paragraph.line_height)
        end
        if anchor ~= self.text_paint.anchor then
            text_paint = self.text_paint:copy_with({ anchor = anchor })
        end
        canvas:draw_text(paragraph, position, text_paint)
        if self.glow_color_override ~= nil then
            local glow_style = paragraph.style:copy_with({
                color = self.glow_color_override,
                blur_radius = self.glow_radius_override or 0,
            })
            canvas:draw_text(Paragraph(paragraph.text, glow_style, paragraph.size,
                paragraph.lines, paragraph.line_height), position, text_paint)
        end
    end
    self:paint_children(canvas, offset)
end

M.RenderText = RenderText

return M
