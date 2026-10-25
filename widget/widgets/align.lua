-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

local std = require 'elxlibs.std'
local geometry = require 'foundation.geometry'
local align_mod = require 'render.align'
local widget_mod = require 'widget.widget'

local Offset = geometry.Offset
local RenderAlign = align_mod.RenderAlign
local SingleChildRenderObjectWidget = widget_mod.SingleChildRenderObjectWidget

---@class _AlignOptions
---@field alignment? Offset
---@field width_factor? number
---@field height_factor? number
---@field key? any

---@class _CenterOptions
---@field width_factor? number
---@field height_factor? number
---@field key? any

---@class Align : SingleChildRenderObjectWidget
---@field alignment Offset
---@field width_factor? number
---@field height_factor? number
---@overload fun(child: Widget?, options?: _AlignOptions): self
local Align = std.class.new('Align', { SingleChildRenderObjectWidget })

---@param child Widget?
---@param options? _AlignOptions
function Align:__init(child, options)
    options = options or {}
    self.key = options.key
    self.child = child
    self.alignment = options.alignment or Offset(0.5, 0.5)
    self.width_factor = options.width_factor
    self.height_factor = options.height_factor
end

function Align:create_render_object()
    return RenderAlign(self.alignment, nil, self.width_factor, self.height_factor)
end

---@param render_object RenderAlign
function Align:update_render_object(render_object)
    render_object.alignment = self.alignment
    render_object.width_factor = self.width_factor
    render_object.height_factor = self.height_factor
    render_object:mark_needs_layout()
end

---@param child Widget?
---@param options? _CenterOptions
---@return Align
local function Center(child, options)
    options = options or {}
    return Align(child, {
        key = options.key,
        alignment = Offset(0.5, 0.5),
        width_factor = options.width_factor,
        height_factor = options.height_factor,
    })
end

return { Align = Align, Center = Center }
