-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Single-child box that overrides its constraints (Flutter's
-- `RenderConstrainedBox` as used by `SizedBox`).
--
-- The widget's `width`/`height` become *additional* constraints: they are
-- combined with the incoming constraints through `enforce` (intersection), so a
-- `SizedBox` can never talk its child into a size its parent forbade — this is
-- the rule behind the "Why is my SizedBox ignored?" note in the SizedBox docs.
-- With no child the missing axes are treated as zero, again after `enforce`.

local std = require 'elxlibs.std'
local geometry = require 'foundation.geometry'
local constraints_mod = require 'layout.constraints'
local render_object = require 'render.render_object'

local Offset = geometry.Offset
local Size = geometry.Size
local Constraints = constraints_mod.Constraints
local RenderObject = render_object.RenderObject

local M = {}

---@class RenderSizedBox : RenderObject
---@field width number?
---@field height number?
---@overload fun(width: number?, height: number?, child: RenderObject?): self
local RenderSizedBox = std.class.new('RenderSizedBox', { RenderObject })

function RenderSizedBox:__init(width, height, child)
    std.super(RenderSizedBox, self, RenderObject).__init(self)
    self.width = width
    self.height = height
    if child then
        self:adopt_child(child)
    end
end

function RenderSizedBox:__perform_layout(constraints)
    local child = self._children[1]
    -- `BoxConstraints.tightFor(width, height)`: null means 0..infinity.
    local additional = Constraints.tight_for({ width = self.width, height = self.height })
    -- Impose the additional constraints *on top of* the parent's, never
    -- replacing them.
    local inner = additional:enforce(constraints)

    if child then
        child:layout(inner)
        child.parent_data.offset = Offset.zero()
        self.size = child.size
    else
        -- No child: null axes are zero, then constrained.
        self.size = inner:constrain_size(Size(0, 0))
    end
end

M.RenderSizedBox = RenderSizedBox

return M
