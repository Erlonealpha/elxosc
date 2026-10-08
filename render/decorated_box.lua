-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Single-child box that paints a background/border behind its child
-- (Flutter's `RenderDecoratedBox`, with a small `Decoration` value).

local std = require 'elxlibs.std'
local geometry = require 'foundation.geometry'
local paint_mod = require 'painting.paint'
local render_object = require 'render.render_object'

local Offset = geometry.Offset
local Size = geometry.Size
local Rect = geometry.Rect
local Paint = paint_mod.Paint
local Style = paint_mod.Style
local RenderObject = render_object.RenderObject

---@class elxdecoration
local M = {}

---@class Decoration
---@field color Color?
---@field radius number
---@field border_width number
---@field border_color Color?
---@overload fun(options: { color: Color?, radius: number?, border_width: number?, border_color: Color? }?): Decoration
local Decoration = std.class.new('Decoration')

function Decoration:__init(options)
    options = options or {}
    self.color = options.color
    self.radius = options.radius or 0
    self.border_width = options.border_width or 0
    self.border_color = options.border_color
end

---@class RenderDecoratedBox : RenderObject
---@field decoration Decoration
---@overload fun(decoration: Decoration, child: RenderObject?): RenderDecoratedBox
local RenderDecoratedBox = std.class.new('RenderDecoratedBox', { RenderObject })

function RenderDecoratedBox:__init(decoration, child)
    std.super(RenderDecoratedBox, self, RenderObject).__init(self)
    self.decoration = decoration
    if child then
        self:adopt_child(child)
    end
end

function RenderDecoratedBox:__perform_layout(constraints)
    local child = self._children[1]
    if child then
        child:layout(constraints)
        child.parent_data.offset = Offset.zero()
        self.size = child.size
    else
        self.size = constraints:constrain_size(Size(0, 0))
    end
end

function RenderDecoratedBox:__paint(canvas, offset)
    local decoration = self.decoration
    local rect = Rect.from_offset_size(offset, self.size)
    if decoration.color then
        local fill = Paint(decoration.color)
        if decoration.radius > 0 then
            canvas:draw_rrect(rect, decoration.radius, fill)
        else
            canvas:draw_rect(rect, fill)
        end
    end
    if decoration.border_width > 0 and decoration.border_color then
        local stroke = Paint(decoration.border_color, Style.STROKE, decoration.border_width)
        if decoration.radius > 0 then
            canvas:draw_rrect(rect, decoration.radius, stroke)
        else
            canvas:draw_rect(rect, stroke)
        end
    end
    self:paint_children(canvas, offset)
end

M.Decoration = Decoration
M.RenderDecoratedBox = RenderDecoratedBox

return M
