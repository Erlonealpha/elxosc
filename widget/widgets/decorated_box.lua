-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

local std = require 'elxlibs.std'
local decorated_box_mod = require 'render.decorated_box'
local widget_mod = require 'widget.widget'

local Decoration = decorated_box_mod.Decoration
local RenderDecoratedBox = decorated_box_mod.RenderDecoratedBox
local SingleChildRenderObjectWidget = widget_mod.SingleChildRenderObjectWidget

---@class _DecoratedBoxOptions
---@field decoration? Decoration
---@field key? any
---@field id? string

---@class DecoratedBox : SingleChildRenderObjectWidget
---@field decoration Decoration
---@overload fun(child: Widget?, options?: _DecoratedBoxOptions): DecoratedBox
local DecoratedBox = std.class.new('DecoratedBox', { SingleChildRenderObjectWidget })

---@param child Widget?
---@param options? _DecoratedBoxOptions
function DecoratedBox:__init(child, options)
    options = options or {}
    self.key = options.key
    self.id = options.id
    self.child = child
    self.decoration = options.decoration or Decoration()
end

function DecoratedBox:create_render_object()
    return RenderDecoratedBox(self.decoration)
end

---@param render_object RenderDecoratedBox
function DecoratedBox:update_render_object(render_object)
    render_object.decoration = self.decoration
    render_object:mark_needs_paint()
end

return { Decoration = Decoration, DecoratedBox = DecoratedBox }
