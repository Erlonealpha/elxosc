-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

---@diagnostic disable: undefined-field, inject-field, generic-constraint-mismatch

local std = require 'elxlibs.std'
local Constraints = require('layout.constraints').Constraints
local render = require 'render.constrained_box'
local SingleChildRenderObjectWidget = require('widget.widget').SingleChildRenderObjectWidget

local ConstrainedBox = std.class.new('ConstrainedBox', { SingleChildRenderObjectWidget })
function ConstrainedBox:__init(options)
    options = options or {}
    self.key, self.id, self.child = options.key, options.id, options.child
    self.constraints = options.constraints or Constraints.unbounded()
end
function ConstrainedBox:create_render_object() return render.RenderConstrainedBox(self.constraints) end
function ConstrainedBox:update_render_object(render_object)
    render_object.additional = self.constraints
    render_object:mark_needs_layout()
end

local LimitedBox = std.class.new('LimitedBox', { SingleChildRenderObjectWidget })
function LimitedBox:__init(options)
    options = options or {}
    self.key, self.id, self.child = options.key, options.id, options.child
    self.max_width, self.max_height = options.max_width, options.max_height
end
function LimitedBox:create_render_object() return render.RenderLimitedBox(self.max_width, self.max_height) end
function LimitedBox:update_render_object(render_object)
    render_object.max_width, render_object.max_height = self.max_width or math.huge, self.max_height or math.huge
    render_object:mark_needs_layout()
end

return { ConstrainedBox = ConstrainedBox, LimitedBox = LimitedBox }
