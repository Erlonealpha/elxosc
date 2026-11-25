-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- A Canvas that records every drawing call instead of producing output.
--
-- Two uses: it is the reference "backend" the test-suite asserts against, and
-- it is the building block for offline golden/snapshot tests of a whole UI
-- tree (there is no mpv in either case).

---@namespace elxosc
---@using elxosc

local std = require 'elxlibs.std'
local canvas = require 'src.painting.canvas'

local ipairs = ipairs
local select = select

local Canvas = canvas.Canvas

---@class mod.src.backends.record
local M = {}

---@class RecordCanvas: Canvas
---@field ops table[]
---@overload fun(): self
local RecordCanvas = std.class.new('RecordCanvas', Canvas)

function RecordCanvas:__init()
    self.ops = {}
end

---@param name string
---@param ...  any
function RecordCanvas:_add(name, ...)
    self.ops[#self.ops + 1] = { name = name, n = select('#', ...), ... }
end

---@return string[]
function RecordCanvas:names()
    local names = {}
    for i, op in ipairs(self.ops) do
        names[i] = op.name
    end
    return names
end

---@param name string
---@return integer
function RecordCanvas:count(name)
    local total = 0
    for _, op in ipairs(self.ops) do
        if op.name == name then
            total = total + 1
        end
    end
    return total
end

function RecordCanvas:reset()
    self.ops = {}
end

function RecordCanvas:save()
    self:_add('save')
end

function RecordCanvas:restore()
    self:_add('restore')
end

---@param dx number
---@param dy number
function RecordCanvas:translate(dx, dy)
    self:_add('translate', dx, dy)
end

---@param sx number
---@param sy number?
function RecordCanvas:scale(sx, sy)
    self:_add('scale', sx, sy)
end

---@param rect Rect
function RecordCanvas:clip_rect(rect)
    self:_add('clip_rect', rect)
end

---@param opacity number
function RecordCanvas:opacity(opacity)
    self:_add('opacity', opacity)
end

---@param rect  Rect
---@param paint Paint
function RecordCanvas:draw_rect(rect, paint)
    self:_add('draw_rect', rect, paint)
end

---@param rect   Rect
---@param radius number
---@param paint  Paint
function RecordCanvas:draw_rrect(rect, radius, paint)
    self:_add('draw_rrect', rect, radius, paint)
end

---@param path  Path
---@param paint Paint
function RecordCanvas:draw_path(path, paint)
    self:_add('draw_path', path, paint)
end

---@param from  Offset
---@param to    Offset
---@param paint Paint
function RecordCanvas:draw_line(from, to, paint)
    self:_add('draw_line', from, to, paint)
end

---@param paragraph  Paragraph
---@param position   Offset
---@param text_paint TextPaint?
function RecordCanvas:draw_text(paragraph, position, text_paint)
    self:_add('draw_text', paragraph, position, text_paint)
end

---@param image Image?
---@param rect  Rect
function RecordCanvas:draw_image(image, rect)
    self:_add('draw_image', image, rect)
end

M.RecordCanvas = RecordCanvas

return M
