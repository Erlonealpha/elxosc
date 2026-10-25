-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

local std = require 'elxlibs.std'
local geometry = require 'foundation.geometry'
local overflow_mod = require 'render.overflow_box'
local fitted_mod = require 'render.fitted_box'
local widget_mod = require 'widget.widget'

local Offset = geometry.Offset
local RenderUnconstrainedBox = overflow_mod.RenderUnconstrainedBox
local RenderOverflowBox = overflow_mod.RenderOverflowBox
local RenderFittedBox = fitted_mod.RenderFittedBox
local SingleChildRenderObjectWidget = widget_mod.SingleChildRenderObjectWidget
local raise = std.raise

local FITS = {
    contain = true,
    cover = true,
    fill = true,
    fit_width = true,
    fit_height = true,
    none = true,
    scale_down = true,
}

---@class _UnconstrainedBoxOptions
---@field child? Widget
---@field alignment? Offset
---@field key? any

---@class _OverflowBoxOptions
---@field child? Widget
---@field min_width? number
---@field max_width? number
---@field min_height? number
---@field max_height? number
---@field fit? OverflowBoxFit
---@field alignment? Offset
---@field key? any

---@class _FittedBoxOptions
---@field fit? FittedBoxFit
---@field alignment? Offset
---@field clip? boolean
---@field key? any

---@class UnconstrainedBox : SingleChildRenderObjectWidget
---@field alignment Offset
---@overload fun(options?: _UnconstrainedBoxOptions): self
local UnconstrainedBox = std.class.new('UnconstrainedBox', { SingleChildRenderObjectWidget })

---@param options? _UnconstrainedBoxOptions
function UnconstrainedBox:__init(options)
    options = options or {}
    self.key = options.key
    self.child = options.child
    self.alignment = options.alignment or Offset(0.5, 0.5)
end

function UnconstrainedBox:create_render_object()
    return RenderUnconstrainedBox(nil, self.alignment)
end

---@param render_object RenderUnconstrainedBox
function UnconstrainedBox:update_render_object(render_object)
    render_object.alignment = self.alignment
    render_object:mark_needs_layout()
end

---@class OverflowBox : SingleChildRenderObjectWidget
---@field opts OverflowBoxOpts
---@overload fun(options?: _OverflowBoxOptions): self
local OverflowBox = std.class.new('OverflowBox', { SingleChildRenderObjectWidget })

---@param options? _OverflowBoxOptions
function OverflowBox:__init(options)
    options = options or {}
    self.key = options.key
    self.child = options.child
    self.opts = {
        min_width = options.min_width,
        max_width = options.max_width,
        min_height = options.min_height,
        max_height = options.max_height,
        fit = options.fit,
        alignment = options.alignment,
    }
end

function OverflowBox:create_render_object()
    return RenderOverflowBox(nil, self.opts)
end

---@param render_object RenderOverflowBox
function OverflowBox:update_render_object(render_object)
    render_object.opts = self.opts
    render_object.alignment = self.opts.alignment or Offset(0.5, 0.5)
    render_object.fit = self.opts.fit or 'max'
    render_object:mark_needs_layout()
end

---@class FittedBox : SingleChildRenderObjectWidget
---@field fit FittedBoxFit
---@field alignment Offset
---@overload fun(child: Widget?, options?: _FittedBoxOptions): self
local FittedBox = std.class.new('FittedBox', { SingleChildRenderObjectWidget })

---@param child Widget?
---@param options? _FittedBoxOptions
function FittedBox:__init(child, options)
    options = options or {}
    self.key = options.key
    self.child = child
    self.fit = options.fit or 'contain'
    self.alignment = options.alignment or Offset(0.5, 0.5)
    if options.clip == nil then
        self.clip = false
    else
        self.clip = options.clip
    end
    if not FITS[self.fit] then
        raise(std.ValueError('FittedBox.fit is not supported: ' .. tostring(self.fit)))
    end
    if type(self.clip) ~= 'boolean' then
        raise(std.TypeError('FittedBox.clip must be a boolean'))
    end
end

function FittedBox:create_render_object()
    return RenderFittedBox(nil, {
        fit = self.fit,
        alignment = self.alignment,
        clip = self.clip,
    })
end

---@param render_object RenderFittedBox
function FittedBox:update_render_object(render_object)
    render_object.fit = self.fit
    render_object.alignment = self.alignment
    render_object.clip = self.clip
    render_object:mark_needs_layout()
end

return {
    UnconstrainedBox = UnconstrainedBox,
    OverflowBox = OverflowBox,
    FittedBox = FittedBox
}
