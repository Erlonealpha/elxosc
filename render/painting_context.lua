-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Minimal Flutter-like PaintingContext for the single Canvas backend.  Layer
-- trees and compositing are deliberately not part of this contract.

local std = require 'elxlibs.std'
local geometry = require 'foundation.geometry'

local Offset = geometry.Offset

local M = {}

---@class PaintingContext : std.object
---@field canvas Canvas
---@field estimated_bounds Rect?
---@overload fun(canvas: Canvas, estimated_bounds: Rect?): self
local PaintingContext = std.class.new('PaintingContext', {})

function PaintingContext:__init(canvas, estimated_bounds)
    self.canvas = canvas
    self.estimated_bounds = estimated_bounds
end

---@param child RenderObject
---@param offset Offset
function PaintingContext:paint_child(child, offset)
    child:paint(self, offset)
end

---@param children RenderObject[]
---@param offset Offset
function PaintingContext:paint_children(children, offset)
    for _, child in ipairs(children) do
        local child_offset = offset
        if child.parent_data and child.parent_data.offset then
            child_offset = (offset + child.parent_data.offset) --[[@as Offset]]
        end
        self:paint_child(child, child_offset)
    end
end

---@param rect Rect
---@param painter fun()
function PaintingContext:clip_rect_and_paint(rect, painter)
    self.canvas:save()
    self.canvas:clip_rect(rect)
    local ok, err = pcall(painter)
    self.canvas:restore()
    if not ok then
        error(err, 0)
    end
end

-- Existing RenderObject implementations can still call Canvas methods on
-- their paint argument while the public boundary migrates to this context.
function PaintingContext:save()
    return self.canvas:save()
end

function PaintingContext:restore()
    return self.canvas:restore()
end

function PaintingContext:translate(dx, dy)
    return self.canvas:translate(dx, dy)
end

function PaintingContext:scale(sx, sy)
    return self.canvas:scale(sx, sy)
end

function PaintingContext:clip_rect(rect)
    return self.canvas:clip_rect(rect)
end

function PaintingContext:draw_rect(rect, paint)
    return self.canvas:draw_rect(rect, paint)
end

function PaintingContext:draw_rrect(rect, radius, paint)
    return self.canvas:draw_rrect(rect, radius, paint)
end

function PaintingContext:draw_path(path, paint)
    return self.canvas:draw_path(path, paint)
end

function PaintingContext:draw_line(from, to, paint)
    return self.canvas:draw_line(from, to, paint)
end

function PaintingContext:draw_text(paragraph, position, text_paint)
    return self.canvas:draw_text(paragraph, position, text_paint)
end

function PaintingContext:draw_image(image, rect)
    return self.canvas:draw_image(image, rect)
end

M.PaintingContext = PaintingContext

return M
