-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Text widget.

local std = require 'elxlibs.std'
local text_style = require 'text.text_style'
local text_paint_mod = require 'painting.text_paint'
local text_mod = require 'render.text'
local widget_mod = require 'widget.widget'

local TextStyle = text_style.TextStyle
local RenderText = text_mod.RenderText
local LeafRenderObjectWidget = widget_mod.LeafRenderObjectWidget

local M = {}

---@class _TextOptions
---@field style TextStyle?
---@field text_layout TextLayout?
---@field text_paint TextPaint?
---@field key any?
---@field id string?

---@class Text : LeafRenderObjectWidget
---@field text string
---@field style TextStyle
---@field text_layout TextLayout?
---@field text_paint TextPaint
---@overload fun(text: string | number, options: _TextOptions?): self
local Text = std.class.new('Text', { LeafRenderObjectWidget })

---@param text string | number
---@param options _TextOptions?
function Text:__init(text, options)
    options = options or {}
    self.key = options.key
    self.id = options.id
    self.text = tostring(text)
    self.style = options.style or TextStyle()
    self.text_layout = options.text_layout
    self.text_paint = text_paint_mod.resolve(options.text_paint)
end

function Text:create_render_object()
    return RenderText(self.text, self.style, self.text_layout, self.text_paint)
end

---@param render_object RenderText
function Text:update_render_object(render_object)
    local layout_changed = render_object.text ~= self.text
        or render_object.style ~= self.style
        or not rawequal(render_object.text_layout, self.text_layout)
    local paint_changed = render_object.text_paint ~= self.text_paint
    render_object.text = self.text
    render_object.style = self.style
    render_object.text_layout = self.text_layout
    render_object.text_paint = self.text_paint
    if layout_changed then
        render_object:mark_needs_layout()
    elseif paint_changed then
        render_object:mark_needs_paint()
    end
end

M.Text = Text

return M
