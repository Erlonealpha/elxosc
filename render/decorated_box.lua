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

local M = {}

---@class _DecorationOptions
---@field color Color?
---@field radius number?
---@field border_width number?
---@field border_color Color?
---@field shadow_color Color?
---@field shadow_offset Offset?
---@field shadow_radius number?

---@class Decoration : std.object
---@field color Color?
---@field radius number
---@field border_width number
---@field border_color Color?
---@field shadow_color Color?
---@field shadow_offset Offset?
---@field shadow_radius number?
---@overload fun(options: _DecorationOptions?): self
local Decoration = std.class.new('Decoration', {})

function Decoration:__init(options)
    options = options or {}
    self.color = options.color
    self.radius = options.radius or 0
    self.border_width = options.border_width or 0
    self.border_color = options.border_color
    self.shadow_color = options.shadow_color
    self.shadow_offset = options.shadow_offset or Offset(0, 2)
    self.shadow_radius = options.shadow_radius or 0
end

---@class RenderDecoratedBox : RenderObject
---@field decoration Decoration
---@overload fun(decoration: Decoration, child: RenderObject?): self
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
    if decoration.shadow_color then
        local shadow_offset = decoration.shadow_offset or Offset(0, 2)
        local shadow_radius = decoration.shadow_radius or 0
        local shadow_rect = Rect.from_offset_size(
            offset:translate(shadow_offset.x, shadow_offset.y), self.size)
        local shadow = Paint(decoration.shadow_color)
        if decoration.radius > 0 then
            canvas:draw_rrect(shadow_rect, decoration.radius + shadow_radius, shadow)
        else
            canvas:draw_rect(shadow_rect, shadow)
        end
    end
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
