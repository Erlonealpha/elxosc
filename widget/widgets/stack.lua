-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

local std = require 'elxlibs.std'
local geometry = require 'foundation.geometry'
local stack_mod = require 'render.stack'
local widget_mod = require 'widget.widget'

local Offset = geometry.Offset
local RenderStack = stack_mod.RenderStack
local MultiChildRenderObjectWidget = widget_mod.MultiChildRenderObjectWidget

---@class _StackOptions
---@field children? Widget[]
---@field alignment? Offset
---@field key? any

---@class Stack : MultiChildRenderObjectWidget
---@field children Widget[]
---@field alignment Offset
---@overload fun(options?: _StackOptions): self
local Stack = std.class.new('Stack', { MultiChildRenderObjectWidget })

---@param options? _StackOptions
function Stack:__init(options)
    options = options or {}
    self.key = options.key
    self.children = options.children or {}
    -- `Stack.alignment` defaults to `AlignmentDirectional.topStart`.
    self.alignment = options.alignment or Offset(0, 0)
end

function Stack:create_render_object()
    return RenderStack({ alignment = self.alignment })
end

---@param render_object RenderStack
function Stack:update_render_object(render_object)
    render_object.alignment = self.alignment
    render_object:mark_needs_layout()
end

return { Stack = Stack }
