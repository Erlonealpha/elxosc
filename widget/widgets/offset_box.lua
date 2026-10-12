-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Declarative front end for RenderOffsetBox.

local std = require 'elxlibs.std'
local geometry = require 'foundation.geometry'
local offset_box_mod = require 'render.offset_box'
local widget_mod = require 'widget.widget'

local Offset = geometry.Offset
local RenderOffsetBox = offset_box_mod.RenderOffsetBox
local SingleChildRenderObjectWidget = widget_mod.SingleChildRenderObjectWidget

---@class _OffsetBoxOptions
---@field offset? Offset defaults to Offset.zero()
---@field child? Widget
---@field key? any
---@field id? string

---@class OffsetBox : SingleChildRenderObjectWidget
---@field offset Offset
---@overload fun(options?: _OffsetBoxOptions): self
local OffsetBox = std.class.new('OffsetBox', { SingleChildRenderObjectWidget })

---@param options? _OffsetBoxOptions
function OffsetBox:__init(options)
    options = options or {}
    self.key = options.key
    self.id = options.id
    self.offset = options.offset or Offset.zero()
    self.child = options.child
end

function OffsetBox:create_render_object()
    return RenderOffsetBox(self.offset)
end

---@param render_object RenderOffsetBox
function OffsetBox:update_render_object(render_object)
    render_object:set_offset(self.offset)
end

return { OffsetBox = OffsetBox }
