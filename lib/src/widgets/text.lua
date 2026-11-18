-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Text widget.

---@namespace elxosc
---@using elxosc

local std = require 'elxlibs.std'
local text_style = require 'src.text.text_style'
local text_paint_mod = require 'src.painting.text_paint'
local text_mod = require 'src.render.text'
local widget_mod = require 'src.widgets.framework'
local ambient_mod = require 'src.widgets.ambient'

local TextStyle = text_style.TextStyle
local RenderText = text_mod.RenderText
local DefaultTextStyle = ambient_mod.DefaultTextStyle
local TextLayoutScope = ambient_mod.TextLayoutScope
local LeafRenderObjectWidget = widget_mod.LeafRenderObjectWidget
local StatelessWidget = widget_mod.StatelessWidget

---@class mod.src.widgets.text
local M = {}

---@class _TextOptions
---@field style TextStyle?
---@field text_layout TextLayout?
---@field text_paint TextPaint?
---@field key any?

---@class TextRenderObjectWidget : LeafRenderObjectWidget
---@field text string
---@field style TextStyle
---@field text_layout TextLayout?
---@field text_paint TextPaint
---@field generation integer
---@overload fun(text: string, style: TextStyle, text_layout: TextLayout?, text_paint: TextPaint, generation?: integer): self
local TextRenderObjectWidget = std.class.new('TextRenderObjectWidget', LeafRenderObjectWidget)

function TextRenderObjectWidget:__init(text, style, text_layout, text_paint, generation)
    self.text = text
    self.style = style
    self.text_layout = text_layout
    self.text_paint = text_paint
    self.generation = generation or 0
end

function TextRenderObjectWidget:create_render_object()
    local render_object = RenderText(self.text, self.style, self.text_layout, self.text_paint)
    render_object.text_layout_generation = self.generation
    return render_object
end

---@param render_object RenderText
function TextRenderObjectWidget:update_render_object(render_object)
    local layout_changed = render_object.text ~= self.text
        or render_object.style ~= self.style
        or not rawequal(render_object.text_layout, self.text_layout)
        or render_object.text_layout_generation ~= self.generation
    local paint_changed = render_object.text_paint ~= self.text_paint
    render_object.text = self.text
    render_object.style = self.style
    render_object.text_layout = self.text_layout
    render_object.text_layout_generation = self.generation
    render_object.text_paint = self.text_paint
    if layout_changed then
        render_object:mark_needs_layout()
    elseif paint_changed then
        render_object:mark_needs_paint()
    end
end

---@class Text : StatelessWidget
---@field text string
---@field style TextStyle?
---@field text_layout TextLayout?
---@field text_paint TextPaint
---@overload fun(text: string | number, options: _TextOptions?): self
local Text = std.class.new('Text', StatelessWidget)

---@param text string | number
---@param options _TextOptions?
function Text:__init(text, options)
    options = options or {}
    self.key = options.key
    self.text = tostring(text)
    self.style = options.style
    self.text_layout = options.text_layout
    self.text_paint = text_paint_mod.resolve(options.text_paint)
    if self.style ~= nil and not std.isinstance(self.style, TextStyle) then
        error('Text.style must be a TextStyle', 2)
    end
end

function Text:build(context)
    local style = self.style
    if style == nil then
        local inherited = DefaultTextStyle.maybe_of(context)
        style = inherited and inherited.style or TextStyle()
    end
    local scope = self.text_layout == nil and TextLayoutScope.maybe_of(context) or nil
    local layout = self.text_layout or (scope and scope.layout)
    return TextRenderObjectWidget(self.text, style, layout, self.text_paint, scope and scope.generation)
end

M.Text = Text

return M
