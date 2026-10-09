-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

---@diagnostic disable: undefined-field, inject-field, generic-constraint-mismatch

local std = require 'elxlibs.std'
local Offset = require('foundation.geometry').Offset
local render = require 'render.overflow_box'
local fitted = require 'render.fitted_box'
local SingleChildRenderObjectWidget = require('widget.widget').SingleChildRenderObjectWidget

local UnconstrainedBox = std.class.new('UnconstrainedBox', { SingleChildRenderObjectWidget })
function UnconstrainedBox:__init(options)
    options = options or {}
    self.key, self.id, self.child = options.key, options.id, options.child
    self.alignment = options.alignment or Offset(0.5, 0.5)
end
function UnconstrainedBox:create_render_object() return render.RenderUnconstrainedBox(nil, self.alignment) end
function UnconstrainedBox:update_render_object(r) r.alignment = self.alignment; r:mark_needs_layout() end

local OverflowBox = std.class.new('OverflowBox', { SingleChildRenderObjectWidget })
function OverflowBox:__init(options)
    options = options or {}
    self.key, self.id, self.child = options.key, options.id, options.child
    self.opts = { min_width = options.min_width, max_width = options.max_width, min_height = options.min_height,
        max_height = options.max_height, fit = options.fit, alignment = options.alignment }
end
function OverflowBox:create_render_object() return render.RenderOverflowBox(nil, self.opts) end
function OverflowBox:update_render_object(r)
    r.opts, r.alignment, r.fit = self.opts, self.opts.alignment or Offset(0.5, 0.5), self.opts.fit or 'max'
    r:mark_needs_layout()
end

local FittedBox = std.class.new('FittedBox', { SingleChildRenderObjectWidget })
function FittedBox:__init(child, options)
    options = options or {}
    self.key, self.id, self.child = options.key, options.id, child
    self.fit, self.alignment = options.fit or 'contain', options.alignment or Offset(0.5, 0.5)
end
function FittedBox:create_render_object() return fitted.RenderFittedBox(nil, { fit = self.fit, alignment = self.alignment }) end
function FittedBox:update_render_object(r) r.fit, r.alignment = self.fit, self.alignment; r:mark_needs_layout() end

return { UnconstrainedBox = UnconstrainedBox, OverflowBox = OverflowBox, FittedBox = FittedBox }
