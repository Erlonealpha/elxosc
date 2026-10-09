-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

---@diagnostic disable: undefined-field, inject-field, generic-constraint-mismatch

local std = require 'elxlibs.std'
local Offset = require('foundation.geometry').Offset
local RenderAlign = require('render.align').RenderAlign
local SingleChildRenderObjectWidget = require('widget.widget').SingleChildRenderObjectWidget

---@class Align : SingleChildRenderObjectWidget
local Align = std.class.new('Align', { SingleChildRenderObjectWidget })
function Align:__init(child, options)
    options = options or {}
    self.key, self.id, self.child = options.key, options.id, child
    self.alignment = options.alignment or Offset(0.5, 0.5)
    self.width_factor, self.height_factor = options.width_factor, options.height_factor
end
function Align:create_render_object()
    return RenderAlign(self.alignment, nil, self.width_factor, self.height_factor)
end
function Align:update_render_object(render_object)
    render_object.alignment, render_object.width_factor = self.alignment, self.width_factor
    render_object.height_factor = self.height_factor
    render_object:mark_needs_layout()
end

local function Center(child, options)
    options = options or {}
    return Align(child, { key = options.key, id = options.id, alignment = Offset(0.5, 0.5),
        width_factor = options.width_factor, height_factor = options.height_factor })
end

return { Align = Align, Center = Center }
