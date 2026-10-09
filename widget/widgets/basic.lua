-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Leaf-ish widgets: text, custom painting and pointer handling.

local std = require 'elxlibs.std'
local text_style = require 'text.text_style'
local geometry = require 'foundation.geometry'
local color_mod = require 'foundation.color'
local text_mod = require 'render.text'
local custom_paint_mod = require 'render.custom_paint'
local gesture_mod = require 'render.gesture'
local widget_mod = require 'widget.widget'
local layout_widgets = require 'widget.widgets.layout'

local TextStyle = text_style.TextStyle
local RenderText = text_mod.RenderText
local RenderCustomPaint = custom_paint_mod.RenderCustomPaint
local RenderGesture = gesture_mod.RenderGesture
local LeafRenderObjectWidget = widget_mod.LeafRenderObjectWidget
local SingleChildRenderObjectWidget = widget_mod.SingleChildRenderObjectWidget
local StatelessWidget = widget_mod.StatelessWidget
local Container = layout_widgets.Container
local EdgeInsets = geometry.EdgeInsets
local Color = color_mod.Color

---@class elxwidgets_basic
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

---@class CustomPaint : SingleChildRenderObjectWidget
---@field draw (fun(canvas: Canvas, offset: Offset, size: Size))?
---@overload fun(options: { draw: fun(canvas: Canvas, offset: Offset, size: Size), preferred_size: Size?, child: Widget?, key: any? }?): CustomPaint
local CustomPaint = std.class.new('CustomPaint', { SingleChildRenderObjectWidget })

function CustomPaint:__init(options)
    options = options or {}
    self.key = options.key
    self.id = options.id
    self.child = options.child
    self.draw = options.draw
    self.preferred_size = options.preferred_size
end

function CustomPaint:create_render_object()
    return RenderCustomPaint(self.draw, { preferred_size = self.preferred_size })
end

function CustomPaint:update_render_object(render_object)
    render_object.draw = self.draw
    render_object.preferred_size = self.preferred_size
    render_object:mark_needs_layout()
end

---@class GestureDetector : SingleChildRenderObjectWidget
---@overload fun(child: Widget?, options: GestureHandlers?): GestureDetector
local GestureDetector = std.class.new('GestureDetector', { SingleChildRenderObjectWidget })

function GestureDetector:__init(child, options)
    options = options or {}
    self.key = options.key
    self.id = options.id
    self.child = child
    self.handlers = options
end

function GestureDetector:create_render_object()
    return RenderGesture(nil, self.handlers)
end

function GestureDetector:update_render_object(render_object)
    render_object.handlers = self.handlers
    if not render_object:wants_pointer('down') then
        render_object.pressed = false
    end
    render_object:mark_needs_paint()
end

--- A basic clickable control. A nil callback or enabled=false leaves mpv's
--- ordinary mouse bindings available. Custom content may replace the label.
---@class Button : StatelessWidget
---@field label string | number?
---@field child Widget?
---@field on_click fun()?
---@field enabled boolean
---@overload fun(options: { label: string | number?, child: Widget?, on_click: fun()?, enabled: boolean?, key: any?, id: string? }): Button
local Button = std.class.new('Button', { StatelessWidget })

function Button:__init(options)
    options = options or {}
    self.key = options.key
    self.id = options.id
    self.label = options.label
    self.child = options.child
    self.on_click = options.on_click
    self.enabled = options.enabled ~= false
end

function Button:build()
    local content = self.child or Text(self.label or '', {
        style = TextStyle(16, { color = Color.rgba255(255, 255, 255) }),
    })
    local body = Container({
        child = content,
        padding = EdgeInsets.symmetric(12, 6),
        color = self.enabled and Color.rgba255(55, 95, 160) or Color.rgba255(85, 85, 85),
        radius = 4,
    })
    if self.enabled and self.on_click then
        return GestureDetector(body, { on_click = function() self.on_click() end })
    end
    return body
end

function Button:child_widgets()
    return self.child and { self.child } or {}
end

function Button:bind_target()
    return 'child'
end

M.Text = Text
M.CustomPaint = CustomPaint
M.GestureDetector = GestureDetector
M.Button = Button

return M
