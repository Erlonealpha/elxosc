-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Text widget.

local std = require 'elxlibs.std'
local text_style = require 'text.text_style'
local text_mod = require 'render.text'
local widget_mod = require 'widget.widget'

local TextStyle = text_style.TextStyle
local RenderText = text_mod.RenderText
local LeafRenderObjectWidget = widget_mod.LeafRenderObjectWidget

local M = {}

---@class Text : LeafRenderObjectWidget
---@field text string
---@field style TextStyle
---@overload fun(text: string | number, options: { style: TextStyle?, text_layout: TextLayout?, key: any? }?): Text
local Text = std.class.new('Text', { LeafRenderObjectWidget })

function Text:__init(text, options)
    options = options or {}
    self.key = options.key
    self.id = options.id
    self.text = tostring(text)
    self.style = options.style or TextStyle()
    self.text_layout = options.text_layout
end

function Text:create_render_object()
    return RenderText(self.text, self.style, self.text_layout)
end

function Text:update_render_object(render_object)
    render_object.text = self.text
    render_object.style = self.style
    render_object.text_layout = self.text_layout
    render_object:mark_needs_layout()
end

M.Text = Text

return M
