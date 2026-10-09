-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- std.class injects widget fields dynamically; keep the module's public class
-- shape consistent with the pre-split aggregate.
---@diagnostic disable: undefined-field, inject-field, generic-constraint-mismatch

local std = require 'elxlibs.std'
local EdgeInsets = require('foundation.geometry').EdgeInsets
local RenderPadding = require('render.padding').RenderPadding
local SingleChildRenderObjectWidget = require('widget.widget').SingleChildRenderObjectWidget

---@class Padding : SingleChildRenderObjectWidget
---@overload fun(child: Widget?, options: { padding: EdgeInsets, key: any? }?): Padding
local Padding = std.class.new('Padding', { SingleChildRenderObjectWidget })

function Padding:__init(child, options)
    options = options or {}
    self.key, self.id, self.child = options.key, options.id, child
    self.padding = options.padding or EdgeInsets.zero()
end

function Padding:create_render_object() return RenderPadding(self.padding) end
function Padding:update_render_object(render_object)
    render_object.padding = self.padding
    render_object:mark_needs_layout()
end

return { Padding = Padding }
