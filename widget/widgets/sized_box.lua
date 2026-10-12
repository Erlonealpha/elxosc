-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

local std = require 'elxlibs.std'
local sized_box_mod = require 'render.sized_box'
local widget_mod = require 'widget.widget'

local RenderSizedBox = sized_box_mod.RenderSizedBox
local SingleChildRenderObjectWidget = widget_mod.SingleChildRenderObjectWidget

---@class _SizedBoxOptions
---@field width? number
---@field height? number
---@field child? Widget
---@field key? any
---@field id? string

---@class _SizedBoxChildOptions
---@field child? Widget
---@field key? any
---@field id? string

---@class SizedBox : SingleChildRenderObjectWidget
---@field width? number
---@field height? number
---@overload fun(options?: _SizedBoxOptions): self
local SizedBox = std.class.new('SizedBox', { SingleChildRenderObjectWidget })

---@param options? _SizedBoxOptions
function SizedBox:__init(options)
    options = options or {}
    self.key = options.key
    self.id = options.id
    self.child = options.child
    self.width = options.width
    self.height = options.height
end

function SizedBox:create_render_object()
    return RenderSizedBox(self.width, self.height)
end

---@param render_object RenderSizedBox
function SizedBox:update_render_object(render_object)
    render_object.width = self.width
    render_object.height = self.height
    render_object:mark_needs_layout()
end

--- Make the box as large as the parent allows (Flutter's `SizedBox.expand`).
---@param options? _SizedBoxChildOptions
---@return SizedBox
function SizedBox.expand(options)
    options = options or {}
    return SizedBox({
        key = options.key,
        id = options.id,
        child = options.child,
        width = math.huge,
        height = math.huge,
    })
end

--- Make the box as small as the parent allows (Flutter's `SizedBox.shrink`).
---@param options? _SizedBoxChildOptions
---@return SizedBox
function SizedBox.shrink(options)
    options = options or {}
    return SizedBox({
        key = options.key,
        id = options.id,
        child = options.child,
        width = 0,
        height = 0,
    })
end

---@param size Size
---@param options? _SizedBoxChildOptions
---@return SizedBox
function SizedBox.from_size(size, options)
    options = options or {}
    return SizedBox({
        key = options.key,
        id = options.id,
        child = options.child,
        width = size.width,
        height = size.height,
    })
end

return { SizedBox = SizedBox }
