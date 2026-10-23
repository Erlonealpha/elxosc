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
local transform_mod = require 'foundation.transform'
local render_object = require 'render.render_object'

local Offset = geometry.Offset
local Size = geometry.Size
local Rect = geometry.Rect
local Constraints = constraints_mod.Constraints
local Matrix2D = transform_mod.Matrix2D
local RenderObject = render_object.RenderObject
local raise = std.raise
local math = math
local min = math.min
local max = math.max

local M = {}

---@alias FittedBoxFit
--- | 'contain'
--- | 'cover'
--- | 'fill'
--- | 'fit_width'
--- | 'fit_height'
--- | 'none'
--- | 'scale_down'

---@class FittedBoxOpts
---@field fit FittedBoxFit?
---@field alignment Offset?
---@field clip boolean? clip the transformed child to this box

---@class RenderFittedBox : RenderObject
---@field fit string
---@field alignment Offset
---@field clip boolean
---@overload fun(child: RenderObject?, options: FittedBoxOpts?): self
local RenderFittedBox = std.class.new('RenderFittedBox', { RenderObject })

---@class FittedBoxMapping
---@field transform Matrix2D
---@field inverse Matrix2D
---@field source_rect Rect
---@field dest_rect Rect
---@field scale_x number
---@field scale_y number

local FITS = {
    contain = true,
    cover = true,
    fill = true,
    fit_width = true,
    fit_height = true,
    none = true,
    scale_down = true,
}

function RenderFittedBox:__init(child, options)
    RenderObject.__init(self)
    options = options or {}
    self.fit = options.fit or 'contain'
    self.alignment = options.alignment or Offset(0.5, 0.5)
    if options.clip == nil then
        self.clip = false
    else
        self.clip = options.clip
    end
    if not FITS[self.fit] then
        raise(std.ValueError('RenderFittedBox.fit is not supported: ' .. tostring(self.fit)))
    end
    if type(self.clip) ~= 'boolean' then
        raise(std.TypeError('RenderFittedBox.clip must be a boolean'))
    end
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

---@return FittedBoxMapping?
function RenderFittedBox:_mapping()
    local child = self._children[1]
    if child == nil or self.size.width <= 0 or self.size.height <= 0
        or child.size.width <= 0 or child.size.height <= 0 then
        return nil
    end
    local source, destination = self:fit_sizes(child.size, self.size)
    if source.width <= 0 or source.height <= 0
        or destination.width <= 0 or destination.height <= 0 then
        return nil
    end
    local source_rect = inscribe(source, Rect.from_offset_size(Offset.zero(), child.size), self.alignment)
    local dest_rect = inscribe(destination, Rect.from_offset_size(Offset.zero(), self.size), self.alignment)
    local scale_x = destination.width / source.width
    local scale_y = destination.height / source.height
    if scale_x <= 0 or scale_y <= 0
        or scale_x == math.huge or scale_y == math.huge
        or scale_x ~= scale_x or scale_y ~= scale_y then
        return nil
    end
    local local_to_box = Matrix2D.translation(dest_rect.left, dest_rect.top)
        :multiply(Matrix2D.scale(scale_x, scale_y))
        :multiply(Matrix2D.translation(-source_rect.left, -source_rect.top))
    local inverse = local_to_box:inverse()
    if inverse == nil then
        return nil
    end
    return {
        transform = local_to_box,
        inverse = inverse,
        source_rect = source_rect,
        dest_rect = dest_rect,
        scale_x = scale_x,
        scale_y = scale_y,
    }
end

---@param canvas PaintingContext
function RenderFittedBox:__paint(canvas, offset)
    local child = self._children[1]
    local mapping = self:_mapping()
    if child == nil or mapping == nil then
        return
    end
    canvas:save()
    if self.clip then
        canvas:clip_rect(Rect.from_offset_size(offset, self.size))
    end
    canvas:translate(offset.x + mapping.dest_rect.left, offset.y + mapping.dest_rect.top)
    canvas:scale(mapping.scale_x, mapping.scale_y)
    canvas:translate(-mapping.source_rect.left, -mapping.source_rect.top)
    child:paint(canvas, Offset.zero())
    canvas:restore()
end

---@param position Offset
---@return RenderObject?
function RenderFittedBox:hit_test(position)
    if not self:__hit_test_bounds(position) then
        return nil
    end
    local child = self._children[1]
    local mapping = self:_mapping()
    if child and mapping then
        local child_position = mapping.inverse:transform_point(position)
        local hit = child:hit_test(child_position)
        if hit then
            return hit
        end
    end
    return self
end

---@param point Offset
---@param out {node: RenderObject, point: Offset}[]?
---@return {node: RenderObject, point: Offset}[]
function RenderFittedBox:pointer_path(point, out)
    out = out or {}
    if not self:__hit_test_bounds(point) then
        return out
    end
    local child = self._children[1]
    local mapping = self:_mapping()
    if child and mapping then
        local child_point = mapping.inverse:transform_point(point)
        if child:__hit_test_bounds(child_point) then
            child:pointer_path(child_point, out)
        end
    end
    out[#out + 1] = { node = self, point = point }
    return out
end

---@param out PointerRegion[]?
---@param local_to_root Matrix2D?
---@return PointerRegion[]
function RenderFittedBox:collect_pointer_regions(out, local_to_root)
    out = out or {}
    local_to_root = local_to_root or Matrix2D.identity()
    self:_append_pointer_region(out, local_to_root)
    local child = self._children[1]
    local mapping = self:_mapping()
    if child and mapping then
        local child_start = #out
        child:collect_pointer_regions(out, local_to_root:multiply(mapping.transform))
        self:_clip_pointer_regions(out, child_start, local_to_root)
    end
    return out
end

M.RenderFittedBox = RenderFittedBox

return M
