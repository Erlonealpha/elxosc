-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Single-child box that scales its child to fit (Flutter's `RenderFittedBox`).
--
-- The child is always laid out *unbounded* so it can take its natural size;
-- `size` then shrinks that natural size to fit while preserving the aspect
-- ratio. Painting applies the resulting scale/translate to the canvas, so the
-- ASS backend only needs one extra tag pair (`\fscx`/`\fscy`) for text.

local std = require 'elxlibs.std'
local geometry = require 'foundation.geometry'
local constraints_mod = require 'layout.constraints'
local render_object = require 'render.render_object'

local Offset = geometry.Offset
local Size = geometry.Size
local Rect = geometry.Rect
local Constraints = constraints_mod.Constraints
local RenderObject = render_object.RenderObject
local math = math
local min = math.min
local max = math.max

local M = {}

---@alias FittedBoxOptsFit
--- | 'contain'
--- | 'cover'
--- | 'fill'
--- | 'fit_width'
--- | 'fit_height'
--- | 'none'
--- | 'scale_down'

---@class FittedBoxOpts
---@field fit FittedBoxOptsFit?
---@field alignment Offset?

---@class RenderFittedBox : RenderObject
---@field fit string
---@field alignment Offset
---@overload fun(child: RenderObject?, options: FittedBoxOpts?): RenderFittedBox
local RenderFittedBox = std.class.new('RenderFittedBox', { RenderObject })

function RenderFittedBox:__init(child, options)
    RenderObject.__init(self)
    options = options or {}
    self.fit = options.fit or 'contain'
    self.alignment = options.alignment or Offset(0.5, 0.5)
    if child then
        self:adopt_child(child)
    end
end

function RenderFittedBox:__perform_layout(constraints)
    local child = self._children[1]
    if child == nil then
        self.size = constraints:smallest()
        return
    end
    child:layout(Constraints.unbounded())
    if self.fit == 'scale_down' then
        local unconstrained = constraints:loosen()
            :constrain_size_and_attempt_to_preserve_aspect_ratio(child.size)
        self.size = constraints:constrain_size(unconstrained)
    else
        self.size = constraints:constrain_size_and_attempt_to_preserve_aspect_ratio(child.size)
    end
end

---@param size Size
---@param rect Rect
---@return Rect
local function inscribe(size, rect, alignment)
    -- `alignment` here is a 0..1 fraction (this framework's convention), not
    -- Flutter's -1..1 `Alignment`.
    local left = rect.left + (rect:width() - size.width) * alignment.x
    local top = rect.top + (rect:height() - size.height) * alignment.y
    return Rect(left, top, left + size.width, top + size.height)
end

--- The `applyBoxFit` result: which part of the child maps where.
---@param child_size Size
---@param size Size
---@return Size source
---@return Size destination
function RenderFittedBox:fit_sizes(child_size, size)
    local cw, ch = child_size.width, child_size.height
    local w, h = size.width, size.height
    if cw == 0 or ch == 0 then
        return Size(0, 0), Size(0, 0)
    end
    local fit = self.fit
    if fit == 'fill' then
        return child_size, size
    elseif fit == 'fit_width' then
        local s = w / cw
        return child_size, Size(w, ch * s)
    elseif fit == 'fit_height' then
        local s = h / ch
        return child_size, Size(cw * s, h)
    elseif fit == 'none' then
        return child_size, child_size
    elseif fit == 'cover' then
        local s = max(w / cw, h / ch)
        return Size(w / s, h / s), size
    end
    -- 'contain' / 'scale_down'
    local s = min(w / cw, h / ch)
    if fit == 'scale_down' then
        s = min(s, 1)
    end
    return child_size, Size(cw * s, ch * s)
end

function RenderFittedBox:__paint(canvas, offset)
    local child = self._children[1]
    if child == nil or self.size.width == 0 or self.size.height == 0 then
        return
    end
    if child.size.width == 0 or child.size.height == 0 then
        return
    end
    local source, destination = self:fit_sizes(child.size, self.size)
    local source_rect = inscribe(source, Rect.from_offset_size(Offset.zero(), child.size), self.alignment)
    local dest_rect = inscribe(destination, Rect.from_offset_size(Offset.zero(), self.size), self.alignment)
    local scale_x = destination.width / source.width
    local scale_y = destination.height / source.height
    canvas:save()
    canvas:translate(offset.x + dest_rect.left, offset.y + dest_rect.top)
    canvas:scale(scale_x, scale_y)
    canvas:translate(-source_rect.left, -source_rect.top)
    child:paint(canvas, Offset.zero())
    canvas:restore()
end

M.RenderFittedBox = RenderFittedBox

return M
