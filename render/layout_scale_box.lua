-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- A positive axis scale that participates in layout. Parent constraints are
-- mapped through the inverse scale before the child is laid out; the scaled
-- child size is then reported to the parent.

local std = require 'elxlibs.std'
local geometry = require 'foundation.geometry'
local constraints_mod = require 'layout.constraints'
local transform_mod = require 'foundation.transform'
local render_object = require 'render.render_object'

local Offset = geometry.Offset
local Rect = geometry.Rect
local Size = geometry.Size
local Constraints = constraints_mod.Constraints
local Matrix2D = transform_mod.Matrix2D
local RenderObject = render_object.RenderObject
local raise = std.raise
local huge = math.huge

local M = {}

---@param value number
---@return boolean
local function is_finite(value)
    return value == value and value ~= huge and value ~= -huge
end

---@class _RenderLayoutScaleBoxOptions
---@field scale Size? positive axis scales; defaults to 1x1
---@field alignment Offset? alignment for extra outer space; defaults to center
---@field clip boolean? clip transformed paint to the layout box; defaults false

---@class RenderLayoutScaleBox : RenderObject
---@field scale Size
---@field alignment Offset
---@field clip boolean
---@field _scale_animation table?
---@overload fun(child: RenderObject?, options?: _RenderLayoutScaleBoxOptions): self
local RenderLayoutScaleBox = std.class.new('RenderLayoutScaleBox', { RenderObject })

---@param scale Size
---@return Size
local function validate_scale(scale)
    if type(scale) ~= 'table'
        or type(scale.width) ~= 'number' or type(scale.height) ~= 'number' then
        raise(std.TypeError('RenderLayoutScaleBox.scale must be a Size'))
    end
    if not is_finite(scale.width) or not is_finite(scale.height)
        or scale.width <= 0 or scale.height <= 0 then
        raise(std.ValueError('RenderLayoutScaleBox.scale must contain positive finite values'))
    end
    return scale
end

---@param alignment Offset
---@return Offset
local function validate_alignment(alignment)
    if type(alignment) ~= 'table'
        or type(alignment.x) ~= 'number' or type(alignment.y) ~= 'number' then
        raise(std.TypeError('RenderLayoutScaleBox.alignment must be an Offset'))
    end
    if not is_finite(alignment.x) or not is_finite(alignment.y)
        or alignment.x < 0 or alignment.x > 1
        or alignment.y < 0 or alignment.y > 1 then
        raise(std.ValueError('RenderLayoutScaleBox.alignment must be between 0 and 1'))
    end
    return alignment
end

---@param value number
---@param scale number
---@return number
local function divide_bound(value, scale)
    if value == huge then
        return huge
    end
    local result = value / scale
    if result == huge or result == -huge or result ~= result then
        raise(std.RuntimeError('RenderLayoutScaleBox scale produces an infinite constraint'))
    end
    return result
end

---@param constraints Constraints
---@param scale Size
---@return Constraints
local function inverse_constraints(constraints, scale)
    return Constraints(
        divide_bound(constraints.min_width, scale.width),
        divide_bound(constraints.max_width, scale.width),
        divide_bound(constraints.min_height, scale.height),
        divide_bound(constraints.max_height, scale.height))
end

---@param value number
---@param scale number
---@return number
local function multiply_size(value, scale)
    local result = value * scale
    if result == huge or result == -huge or result ~= result then
        raise(std.RuntimeError('RenderLayoutScaleBox scale produces an infinite size'))
    end
    return result
end

---@param child RenderObject?
---@param options _RenderLayoutScaleBoxOptions?
function RenderLayoutScaleBox:__init(child, options)
    RenderObject.__init(self)
    options = options or {}
    self.scale = validate_scale(options.scale == nil and Size(1, 1) or options.scale)
    self.alignment = validate_alignment(
        options.alignment == nil and Offset(0.5, 0.5) or options.alignment)
    if options.clip == nil then
        self.clip = false
    else
        self.clip = options.clip
    end
    if type(self.clip) ~= 'boolean' then
        raise(std.TypeError('RenderLayoutScaleBox.clip must be a boolean'))
    end
    self._scale_animation = nil
    if child then
        self:adopt_child(child)
    end
end

---@param scale Size
function RenderLayoutScaleBox:set_scale(scale)
    scale = validate_scale(scale)
    if self.scale == scale then
        return
    end
    self.scale = scale
    self:mark_needs_layout()
end

---@param alignment Offset
function RenderLayoutScaleBox:set_alignment(alignment)
    alignment = validate_alignment(alignment)
    if self.alignment == alignment then
        return
    end
    self.alignment = alignment
    self:mark_needs_paint()
end

---@param clip boolean
function RenderLayoutScaleBox:set_clip(clip)
    if type(clip) ~= 'boolean' then
        raise(std.TypeError('RenderLayoutScaleBox.clip must be a boolean'))
    end
    if self.clip == clip then
        return
    end
    self.clip = clip
    self:mark_needs_paint()
end

---@param constraints Constraints
function RenderLayoutScaleBox:__perform_layout(constraints)
    local child = self._children[1]
    if child == nil then
        self.size = constraints:constrain_size(Size.zero())
        return
    end
    child:layout(inverse_constraints(constraints, self.scale))
    child.parent_data.offset = Offset.zero()
    self.size = constraints:constrain_size(Size(
        multiply_size(child.size.width, self.scale.width),
        multiply_size(child.size.height, self.scale.height)))
end

---@return Matrix2D?
---@return Matrix2D?
function RenderLayoutScaleBox:_mapping()
    local child = self._children[1]
    if child == nil then
        return nil, nil
    end
    local destination = Size(
        multiply_size(child.size.width, self.scale.width),
        multiply_size(child.size.height, self.scale.height))
    local left = (self.size.width - destination.width) * self.alignment.x
    local top = (self.size.height - destination.height) * self.alignment.y
    local matrix = Matrix2D.translation(left, top)
        :multiply(Matrix2D.scale(self.scale.width, self.scale.height))
    return matrix, matrix:inverse()
end

---@param canvas Canvas
---@param offset Offset
function RenderLayoutScaleBox:__paint(canvas, offset)
    local child = self._children[1]
    if child == nil or child.size.width <= 0 or child.size.height <= 0 then
        return
    end
    local destination = Size(
        multiply_size(child.size.width, self.scale.width),
        multiply_size(child.size.height, self.scale.height))
    local left = (self.size.width - destination.width) * self.alignment.x
    local top = (self.size.height - destination.height) * self.alignment.y
    canvas:save()
    if self.clip then
        canvas:clip_rect(Rect.from_offset_size(offset, self.size))
    end
    canvas:translate(offset.x + left, offset.y + top)
    canvas:scale(self.scale.width, self.scale.height)
    child:paint(canvas, Offset.zero())
    canvas:restore()
end

---@param position Offset
---@return RenderObject?
function RenderLayoutScaleBox:hit_test(position)
    if not self:__hit_test_bounds(position) then
        return nil
    end
    local child = self._children[1]
    if child then
        local _, inverse = self:_mapping()
        if inverse then
            local hit = child:hit_test(inverse:transform_point(position))
            if hit then
                return hit
            end
        end
    end
    return self
end

---@param point Offset
---@param out {node: RenderObject, point: Offset}[]?
---@return {node: RenderObject, point: Offset}[]
function RenderLayoutScaleBox:pointer_path(point, out)
    out = out or {}
    if not self:__hit_test_bounds(point) then
        return out
    end
    local child = self._children[1]
    if child then
        local _, inverse = self:_mapping()
        if inverse then
            local child_point = inverse:transform_point(point)
            if child:__hit_test_bounds(child_point) then
                child:pointer_path(child_point, out)
            end
        end
    end
    out[#out + 1] = { node = self, point = point }
    return out
end

---@param out PointerRegion[]?
---@param local_to_root Matrix2D?
---@return PointerRegion[]
function RenderLayoutScaleBox:collect_pointer_regions(out, local_to_root)
    out = out or {}
    local_to_root = local_to_root or Matrix2D.identity()
    self:_append_pointer_region(out, local_to_root)
    local child = self._children[1]
    if child then
        local child_start = #out
        local mapping = self:_mapping()
        if mapping then
            child:collect_pointer_regions(out, local_to_root:multiply(mapping))
            self:_clip_pointer_regions(out, child_start, local_to_root)
        end
    end
    return out
end

---@param controller AnimationController?
---@param tween Tween<Size>?
function RenderLayoutScaleBox:set_scale_animation(controller, tween)
    local current = self._scale_animation
    if current and current.controller == controller and current.tween == tween then
        return
    end
    self:unbind_scale_animation()
    if controller == nil or tween == nil then
        return
    end
    local listener = function()
        self:set_scale(tween:value_at(controller.value))
    end
    controller:add_listener(listener)
    self._scale_animation = { controller = controller, tween = tween, listener = listener }
    listener()
end

function RenderLayoutScaleBox:unbind_scale_animation()
    local binding = self._scale_animation
    if not binding then
        return
    end
    binding.controller:remove_listener(binding.listener)
    self._scale_animation = nil
end

---@param owner RenderOwner?
function RenderLayoutScaleBox:_set_owner(owner)
    RenderObject._set_owner(self, owner)
    if owner == nil then
        self:unbind_scale_animation()
    end
end

M.RenderLayoutScaleBox = RenderLayoutScaleBox

return M
