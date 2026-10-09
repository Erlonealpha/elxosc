-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

---@diagnostic disable: undefined-field, inject-field, generic-constraint-mismatch

local std = require 'elxlibs.std'
local RenderSizedBox = require('render.sized_box').RenderSizedBox
local SingleChildRenderObjectWidget = require('widget.widget').SingleChildRenderObjectWidget

local SizedBox = std.class.new('SizedBox', { SingleChildRenderObjectWidget })
function SizedBox:__init(options)
    options = options or {}
    self.key, self.id = options.key, options.id
    self.child, self.width, self.height = options.child, options.width, options.height
end
function SizedBox:create_render_object() return RenderSizedBox(self.width, self.height) end
function SizedBox:update_render_object(render_object)
    render_object.width, render_object.height = self.width, self.height
    render_object:mark_needs_layout()
end
function SizedBox.expand(options)
    options = options or {}
    return SizedBox({ key = options.key, id = options.id, child = options.child, width = math.huge, height = math.huge })
end
function SizedBox.shrink(options)
    options = options or {}
    return SizedBox({ key = options.key, id = options.id, child = options.child, width = 0, height = 0 })
end
function SizedBox.from_size(size, options)
    options = options or {}
    return SizedBox({ key = options.key, id = options.id, child = options.child, width = size.width, height = size.height })
end

return { SizedBox = SizedBox }
