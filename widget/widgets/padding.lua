-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

local std = require 'elxlibs.std'
local geometry = require 'foundation.geometry'
local padding_mod = require 'render.padding'
local widget_mod = require 'widget.widget'

local EdgeInsets = geometry.EdgeInsets
local RenderPadding = padding_mod.RenderPadding
local SingleChildRenderObjectWidget = widget_mod.SingleChildRenderObjectWidget

---@class _PaddingOptions
---@field padding? EdgeInsets
---@field key? any
---@field id? string

---@class Padding : SingleChildRenderObjectWidget
---@field padding EdgeInsets
---@overload fun(child: Widget?, options?: _PaddingOptions): Padding
local Padding = std.class.new('Padding', { SingleChildRenderObjectWidget })

---@param child Widget?
---@param options? _PaddingOptions
function Padding:__init(child, options)
    options = options or {}
    self.key = options.key
    self.id = options.id
    self.child = child
    self.padding = options.padding or EdgeInsets.zero()
end

function Padding:create_render_object()
    return RenderPadding(self.padding)
end

---@param render_object RenderPadding
function Padding:update_render_object(render_object)
    render_object.padding = self.padding
    render_object:mark_needs_layout()
end

return { Padding = Padding }
