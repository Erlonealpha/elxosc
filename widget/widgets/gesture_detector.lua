-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Pointer gesture detector widget.

local std = require 'elxlibs.std'
local gesture_mod = require 'render.gesture'
local widget_mod = require 'widget.widget'

local RenderGesture = gesture_mod.RenderGesture
local SingleChildRenderObjectWidget = widget_mod.SingleChildRenderObjectWidget

local M = {}

---@class GestureDetector : SingleChildRenderObjectWidget
---@overload fun(child: Widget?, options: GestureHandlers?): self
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

M.GestureDetector = GestureDetector

return M
