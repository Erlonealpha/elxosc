-- Read-only linear progress, including frame-clock driven indeterminate paint.
local std = require 'elxlibs.std'
local geometry = require 'foundation.geometry'
local Color = require('foundation.color').Color
local Paint = require('painting.paint').Paint
local RenderObject = require('render.render_object').RenderObject
local Rect = geometry.Rect
local Size = geometry.Size
local raise = std.raise

local M = {}

local function finite(value, name)
    if type(value) ~= 'number' or value ~= value or value == math.huge or value == -math.huge then
        raise(std.ValueError('LinearProgressIndicator.' .. name .. ' must be finite'))
    end
    return value
end

---@class _LinearProgressIndicatorOptions
---@field value number? nil means indeterminate; finite values are clamped to 0..1
---@field color Color?
---@field background_color Color?
---@field min_height number? default 4
---@field border_radius number? default 2
---@field key any?

---@param options _LinearProgressIndicatorOptions?
---@return _LinearProgressIndicatorOptions
function M.normalize(options)
    options = options or {}
    local value = options.value
    if value ~= nil then
        value = math.max(0, math.min(1, finite(value, 'value')))
    end
    local height = finite(options.min_height == nil and 4 or options.min_height, 'min_height')
    local radius = finite(options.border_radius == nil and 2 or options.border_radius, 'border_radius')
    if height <= 0 or radius < 0 then
        raise(std.ValueError('LinearProgressIndicator height/radius is invalid'))
    end
    local foreground = options.color or Color.rgba255(70, 150, 240)
    local background = options.background_color or Color.rgba255(255, 255, 255, 45)
    if not std.isinstance(foreground, Color) or not std.isinstance(background, Color) then
        raise(std.TypeError('LinearProgressIndicator colors must be Color values'))
    end
    return { key = options.key, value = value, color = foreground, background_color = background,
        min_height = height, border_radius = radius }
end

---@class RenderLinearProgressIndicator : RenderObject, _LinearProgressIndicatorOptions
---@field min_height number
---@field border_radius number
---@field phase number
---@overload fun(options?: _LinearProgressIndicatorOptions): self
local RenderLinearProgressIndicator = std.class.new('RenderLinearProgressIndicator', RenderObject)

function RenderLinearProgressIndicator:__init(options)
    RenderObject.__init(self)
    self.phase = 0
    self:configure(options)
end

---@param options _LinearProgressIndicatorOptions?
function RenderLinearProgressIndicator:configure(options)
    local config = M.normalize(options)
    local layout_changed = self.min_height ~= config.min_height
    local paint_changed = self.value ~= config.value or self.color ~= config.color
        or self.background_color ~= config.background_color or self.border_radius ~= config.border_radius
    self.value = config.value
    self.color = config.color
    self.background_color = config.background_color
    self.min_height = config.min_height
    self.border_radius = config.border_radius
    if layout_changed then
        self:mark_needs_layout()
    elseif paint_changed then
        self:mark_needs_paint()
    end
end

---@param phase number
function RenderLinearProgressIndicator:set_phase(phase)
    phase = finite(phase, 'phase') % 1
    if self.phase ~= phase then
        self.phase = phase
        if self.value == nil then
            self:mark_needs_paint()
        end
    end
end

function RenderLinearProgressIndicator:__perform_layout(constraints)
    local width = constraints.max_width < math.huge and constraints.max_width or 200
    self.size = constraints:constrain_size(Size(width, self.min_height))
end

function RenderLinearProgressIndicator:__paint(canvas, offset)
    local width, height = self.size.width, self.size.height
    if width <= 0 or height <= 0 then
        return
    end
    local radius = math.min(self.border_radius, height / 2, width / 2)
    canvas:draw_rrect(Rect.from_ltwh(offset.x, offset.y, width, height), radius, Paint(self.background_color))
    local function segment(left, right)
        left, right = math.max(0, left), math.min(1, right)
        if right > left then
            canvas:draw_rrect(Rect.from_ltwh(offset.x + left * width, offset.y,
                (right - left) * width, height), radius, Paint(self.color))
        end
    end
    if self.value ~= nil then
        segment(0, self.value)
    else
        -- Two staggered stretches communicate activity without claiming a value.
        for _, shift in ipairs({ 0, 0.5 }) do
            local phase = (self.phase + shift) % 1
            local head = math.min(1, phase * 2)
            local tail = math.max(0, (phase - 0.35) / 0.65)
            segment(tail * tail, 1 - (1 - head) * (1 - head))
        end
    end
end

M.RenderLinearProgressIndicator = RenderLinearProgressIndicator

return M
