-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

local std = require 'elxlibs.std'
local constraints_mod = require 'layout.constraints'
local render_mod = require 'render.constrained_box'
local widget_mod = require 'widget.widget'

local Constraints = constraints_mod.Constraints
local RenderConstrainedBox = render_mod.RenderConstrainedBox
local RenderLimitedBox = render_mod.RenderLimitedBox
local SingleChildRenderObjectWidget = widget_mod.SingleChildRenderObjectWidget

---@class _ConstrainedBoxOptions
---@field child? Widget
---@field constraints? Constraints
---@field key? any
---@field id? string

---@class _LimitedBoxOptions
---@field child? Widget
---@field max_width? number
---@field max_height? number
---@field key? any
---@field id? string

---@class ConstrainedBox : SingleChildRenderObjectWidget
---@field constraints Constraints
---@overload fun(options?: _ConstrainedBoxOptions): self
local ConstrainedBox = std.class.new('ConstrainedBox', { SingleChildRenderObjectWidget })

---@param options? _ConstrainedBoxOptions
function ConstrainedBox:__init(options)
    options = options or {}
    self.key = options.key
    self.id = options.id
    self.child = options.child
    self.constraints = options.constraints or Constraints.unbounded()
end

function ConstrainedBox:create_render_object()
    return RenderConstrainedBox(self.constraints)
end

---@param render_object RenderConstrainedBox
function ConstrainedBox:update_render_object(render_object)
    render_object.additional = self.constraints
    render_object:mark_needs_layout()
end

---@class LimitedBox : SingleChildRenderObjectWidget
---@field max_width? number
---@field max_height? number
---@overload fun(options?: _LimitedBoxOptions): self
local LimitedBox = std.class.new('LimitedBox', { SingleChildRenderObjectWidget })

---@param options? _LimitedBoxOptions
function LimitedBox:__init(options)
    options = options or {}
    self.key = options.key
    self.id = options.id
    self.child = options.child
    self.max_width = options.max_width
    self.max_height = options.max_height
end

function LimitedBox:create_render_object()
    return RenderLimitedBox(self.max_width, self.max_height)
end

---@param render_object RenderLimitedBox
function LimitedBox:update_render_object(render_object)
    render_object.max_width = self.max_width or math.huge
    render_object.max_height = self.max_height or math.huge
    render_object:mark_needs_layout()
end

return { ConstrainedBox = ConstrainedBox, LimitedBox = LimitedBox }
