-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

---@diagnostic disable: undefined-field, inject-field, generic-constraint-mismatch

local std = require 'elxlibs.std'
local decorated = require 'render.decorated_box'
local SingleChildRenderObjectWidget = require('widget.widget').SingleChildRenderObjectWidget

local DecoratedBox = std.class.new('DecoratedBox', { SingleChildRenderObjectWidget })
function DecoratedBox:__init(child, options)
    options = options or {}
    self.key, self.id, self.child = options.key, options.id, child
    self.decoration = options.decoration or decorated.Decoration()
end
function DecoratedBox:create_render_object() return decorated.RenderDecoratedBox(self.decoration) end
function DecoratedBox:update_render_object(render_object)
    render_object.decoration = self.decoration
    render_object:mark_needs_paint()
end

return { Decoration = decorated.Decoration, DecoratedBox = DecoratedBox }
