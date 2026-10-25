-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Declarative front ends for the two finite axis-scale boxes.

local std = require 'elxlibs.std'
local geometry = require 'foundation.geometry'
local transform_box_mod = require 'render.transform_box'
local layout_scale_box_mod = require 'render.layout_scale_box'
local widget_mod = require 'widget.widget'

local Offset = geometry.Offset
local Size = geometry.Size
local RenderTransformBox = transform_box_mod.RenderTransformBox
local RenderLayoutScaleBox = layout_scale_box_mod.RenderLayoutScaleBox
local SingleChildRenderObjectWidget = widget_mod.SingleChildRenderObjectWidget

---@class _TransformBoxOptions
---@field scale? Size positive axis scales; defaults to 1x1
---@field alignment? Offset 0..1 pivot inside the layout box
---@field clip? boolean clip transformed paint to the layout box
---@field scale_controller? AnimationController
---@field scale_tween? Tween<Size>
---@field key? any

---@class TransformBox : SingleChildRenderObjectWidget
---@field scale Size
---@field alignment Offset
---@field clip boolean
---@field scale_controller AnimationController?
---@field scale_tween Tween<Size>?
---@overload fun(child: Widget?, options?: _TransformBoxOptions): self
local TransformBox = std.class.new('TransformBox', { SingleChildRenderObjectWidget })

---@param child Widget?
---@param options? _TransformBoxOptions
function TransformBox:__init(child, options)
    options = options or {}
    self.key = options.key
    self.child = child
    self.scale = options.scale == nil and Size(1, 1) or options.scale
    self.alignment = options.alignment == nil and Offset(0.5, 0.5) or options.alignment
    self.scale_controller = options.scale_controller
    self.scale_tween = options.scale_tween
    if options.clip == nil then
        self.clip = false
    else
        self.clip = options.clip
    end
end

function TransformBox:create_render_object()
    local render_object = RenderTransformBox(nil, {
        scale = self.scale,
        alignment = self.alignment,
        clip = self.clip,
    })
    render_object:set_scale_animation(self.scale_controller, self.scale_tween)
    return render_object
end

---@param render_object RenderTransformBox
function TransformBox:update_render_object(render_object)
    render_object:set_alignment(self.alignment)
    render_object:set_clip(self.clip)
    render_object:set_scale_animation(self.scale_controller, self.scale_tween)
    if self.scale_controller == nil or self.scale_tween == nil then
        render_object:set_scale(self.scale)
    end
end

---@class _LayoutScaleBoxOptions
---@field scale? Size positive axis scales; defaults to 1x1
---@field alignment? Offset 0..1 alignment for extra outer space
---@field clip? boolean clip transformed paint to the layout box
---@field key? any

---@class LayoutScaleBox : SingleChildRenderObjectWidget
---@field scale Size
---@field alignment Offset
---@field clip boolean
---@overload fun(child: Widget?, options?: _LayoutScaleBoxOptions): self
local LayoutScaleBox = std.class.new('LayoutScaleBox', { SingleChildRenderObjectWidget })

---@param child Widget?
---@param options? _LayoutScaleBoxOptions
function LayoutScaleBox:__init(child, options)
    options = options or {}
    self.key = options.key
    self.child = child
    self.scale = options.scale == nil and Size(1, 1) or options.scale
    self.alignment = options.alignment == nil and Offset(0.5, 0.5) or options.alignment
    if options.clip == nil then
        self.clip = false
    else
        self.clip = options.clip
    end
end

function LayoutScaleBox:create_render_object()
    return RenderLayoutScaleBox(nil, {
        scale = self.scale,
        alignment = self.alignment,
        clip = self.clip,
    })
end

---@param render_object RenderLayoutScaleBox
function LayoutScaleBox:update_render_object(render_object)
    render_object:set_scale(self.scale)
    render_object:set_alignment(self.alignment)
    render_object:set_clip(self.clip)
end

return {
    TransformBox = TransformBox,
    LayoutScaleBox = LayoutScaleBox,
}
