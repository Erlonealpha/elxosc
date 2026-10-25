-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Custom painting widget.

local std = require 'elxlibs.std'
local custom_paint_mod = require 'render.custom_paint'
local widget_mod = require 'widget.widget'

local RenderCustomPaint = custom_paint_mod.RenderCustomPaint
local SingleChildRenderObjectWidget = widget_mod.SingleChildRenderObjectWidget

local M = {}

---@class _CustomPaintOptions
---@field draw (fun(canvas: Canvas, offset: Offset, size: Size))?
---@field preferred_size Size?
---@field child Widget?
---@field key any?

---@class CustomPaint : SingleChildRenderObjectWidget
---@field draw (fun(canvas: Canvas, offset: Offset, size: Size))?
---@overload fun(options: _CustomPaintOptions?): self
local CustomPaint = std.class.new('CustomPaint', { SingleChildRenderObjectWidget })

function CustomPaint:__init(options)
    options = options or {}
    self.key = options.key
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

M.CustomPaint = CustomPaint

return M
