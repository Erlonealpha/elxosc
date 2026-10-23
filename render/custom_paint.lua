-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Leaf (optionally wrapping a child) that delegates drawing to a callback
-- (Flutter's `CustomPaint`). This is how user code puts pixels on the canvas
-- without knowing which backend is behind it.
--
-- The callback receives absolute canvas coordinates:
--   draw(canvas, offset, size)

local std = require 'elxlibs.std'
local geometry = require 'foundation.geometry'
local render_object = require 'render.render_object'

local Offset = geometry.Offset
local Size = geometry.Size
local RenderObject = render_object.RenderObject

local M = {}

---@class CustomPaintOpts
---@field child RenderObject?
---@field preferred_size Size?

---@class RenderCustomPaint : RenderObject
---@field draw (fun(canvas: Canvas, offset: Offset, size: Size))?
---@field preferred_size Size?
---@overload fun(draw: (fun(canvas: Canvas, offset: Offset, size: Size))?, options: CustomPaintOpts?): self
local RenderCustomPaint = std.class.new('RenderCustomPaint', { RenderObject })

function RenderCustomPaint:__init(draw, options)
    RenderObject.__init(self)
    options = options or {}
    self.draw = draw
    self.preferred_size = options.preferred_size
    if options.child then
        self:adopt_child(options.child)
    end
end

function RenderCustomPaint:__perform_layout(constraints)
    local child = self._children[1]
    if child then
        -- `RenderProxyBox`: hand the incoming constraints down unchanged and
        -- match the child's size (a loosened box would let the child shrink
        -- below a tight parent).
        child:layout(constraints)
        child.parent_data.offset = Offset.zero()
        self.size = child.size
    else
        -- No child: our preferred size, constrained. Defaults to `Size.zero`
        -- (Flutter's `CustomPaint.size`), not "as big as possible".
        self.size = constraints:constrain_size(self.preferred_size or Size(0, 0))
    end
end

---@param canvas PaintingContext
function RenderCustomPaint:__paint(canvas, offset)
    if self.draw then
        self.draw(canvas.canvas, offset, self.size)
    end
    self:paint_children(canvas, offset)
end

M.RenderCustomPaint = RenderCustomPaint

return M
