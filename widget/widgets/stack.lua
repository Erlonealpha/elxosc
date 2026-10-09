-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

---@diagnostic disable: undefined-field, inject-field, generic-constraint-mismatch

local std = require 'elxlibs.std'
local Offset = require('foundation.geometry').Offset
local RenderStack = require('render.stack').RenderStack
local MultiChildRenderObjectWidget = require('widget.widget').MultiChildRenderObjectWidget

local Stack = std.class.new('Stack', { MultiChildRenderObjectWidget })
function Stack:__init(options)
    options = options or {}
    self.key, self.id = options.key, options.id
    self.children, self.alignment = options.children or {}, options.alignment or Offset(0, 0)
end
function Stack:create_render_object() return RenderStack({ alignment = self.alignment }) end
function Stack:update_render_object(render_object)
    render_object.alignment = self.alignment
    render_object:mark_needs_layout()
end

return { Stack = Stack }
