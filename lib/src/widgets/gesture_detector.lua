-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Pointer gesture detector widget.

---@namespace elxosc
---@using elxosc

local std = require 'elxlibs.std'
local gesture_mod = require 'src.render.gesture'
local widget_mod = require 'src.widgets.framework'

local RenderGesture = gesture_mod.RenderGesture
local SingleChildRenderObjectWidget = widget_mod.SingleChildRenderObjectWidget

---@class mod.src.widgets.gesture_detector
local M = {}

---@class GestureDetector: SingleChildRenderObjectWidget
---@field handlers GestureHandlers
---@overload fun(child: Widget?, options: GestureHandlers?): self
local GestureDetector = std.class.new('GestureDetector', SingleChildRenderObjectWidget)

---@param child   Widget?
---@param options GestureHandlers?
function GestureDetector:__init(child, options)
    options = options or {}
    self.key = options.key
    self.child = child
    self.handlers = options
end

---@return RenderGesture
function GestureDetector:create_render_object()
    return RenderGesture(nil, self.handlers)
end

---@param render_object RenderGesture
function GestureDetector:update_render_object(render_object)
    render_object:set_handlers(self.handlers)
end

M.GestureDetector = GestureDetector

return M
