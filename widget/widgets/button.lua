-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Basic clickable control.

local std = require 'elxlibs.std'
local geometry = require 'foundation.geometry'
local color_mod = require 'foundation.color'
local text_style = require 'text.text_style'
local text_widgets = require 'widget.widgets.text'
local gesture_widgets = require 'widget.widgets.gesture_detector'
local widget_mod = require 'widget.widget'
local Container = require('widget.widgets.container').Container

local TextStyle = text_style.TextStyle
local Text = text_widgets.Text
local GestureDetector = gesture_widgets.GestureDetector
local StatelessWidget = widget_mod.StatelessWidget
local EdgeInsets = geometry.EdgeInsets
local Color = color_mod.Color

---@class elxwidget_button
local M = {}

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

M.Button = Button

return M
