-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Single-child box that insets its child (Flutter's `RenderPadding`).

local std = require 'elxlibs.std'
local geometry = require 'foundation.geometry'
local render_object = require 'render.render_object'

local Offset = geometry.Offset
local Size = geometry.Size
local RenderObject = render_object.RenderObject

---@class elxpadding
local M = {}

---@class RenderPadding : RenderObject
---@field padding EdgeInsets
---@overload fun(padding: EdgeInsets, child: RenderObject?): RenderPadding
local RenderPadding = std.class.new('RenderPadding', { RenderObject })

function RenderPadding:__init(padding, child)
    RenderObject.__init(self)
    self.padding = padding
    if child then
        self:adopt_child(child)
    end
end

function RenderPadding:__perform_layout(constraints)
    local child = self._children[1]
    if child == nil then
        return
    end
    child:layout(constraints:deflate(self.padding))
    child.parent_data.offset = Offset(self.padding.left, self.padding.top)
    self.size = Size(
        child.size.width + self.padding:horizontal(),
        child.size.height + self.padding:vertical())
end

M.RenderPadding = RenderPadding

return M
