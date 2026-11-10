-- Controlled numeric selection; independent of media seek and progress reporting.

local std = require 'elxlibs.std'
local geometry = require 'foundation.geometry'
local color_mod = require 'foundation.color'
local paint_mod = require 'painting.paint'
local render_mod = require 'render.render_object'

local RenderObject = render_mod.RenderObject
local Color = color_mod.Color
local Paint = paint_mod.Paint
local Rect = geometry.Rect
local Size = geometry.Size
local raise = std.raise

---@class elxosc.render.slider
local M = {}

local function finite(value, name)
    if type(value) ~= 'number' or value ~= value or value == math.huge or value == -math.huge then
        raise(std.ValueError('Slider.' .. name .. ' must be finite'))
    end
    return value
end

local function positive(value, name, allow_zero)
    finite(value, name)
    if value < 0 or not allow_zero and value == 0 then
        raise(std.ValueError('Slider.' .. name .. ' has an invalid size'))
    end
    return value
end

local function color(value, name)
    if not std.isinstance(value, Color) then
        raise(std.TypeError('Slider.' .. name .. ' must be a Color'))
    end
    return value
end

local function callback(value, name)
    if value ~= nil and type(value) ~= 'function' then
        raise(std.TypeError('Slider.' .. name .. ' must be a function'))
    end
    return value
end

---@class _SliderOptions
---@field value number? controlled value; default min
---@field min number? inclusive lower bound; default 0
---@field max number? inclusive upper bound; default 1; equal bounds disable input
---@field divisions integer? positive number of intervals
---@field secondary_track_value number? value in the same range
---@field on_changed fun(value: number)? nil disables selection
---@field on_change_start fun(value: number)? previous controlled value
---@field on_change_end fun(value: number)? final drag value; also called on cancellation
---@field active_color Color?
---@field inactive_color Color?
---@field secondary_active_color Color?
---@field thumb_color Color?
---@field disabled_active_color Color?
---@field disabled_inactive_color Color?
---@field disabled_thumb_color Color?
---@field overlay_color Color?
---@field height number? logical layout height; default 48
---@field track_height number? default 4
---@field track_inset number? horizontal padding; default 20
---@field thumb_radius number? default 10
---@field overlay_radius number? default 20
---@field hit_expand number? extra input bounds; default 0
---@field enabled boolean? optional explicit disable
---@field key any?

--- Normalize once at construction/update boundaries, keeping caller data untouched.
---@param options _SliderOptions?
---@return _SliderOptions
function M.normalize(options)
    options = options or {}
    local lower = finite(options.min == nil and 0 or options.min, 'min')
    local upper = finite(options.max == nil and 1 or options.max, 'max')
    if upper < lower or upper - lower == math.huge then
        raise(std.ValueError('Slider.max must be >= min with a finite span'))
    end
    local value = finite(options.value == nil and lower or options.value, 'value')
    if value < lower or value > upper then
        raise(std.ValueError('Slider.value must be between min and max'))
    end
    local secondary = options.secondary_track_value
    if secondary ~= nil and (finite(secondary, 'secondary_track_value') < lower or secondary > upper) then
        raise(std.ValueError('Slider.secondary_track_value must be between min and max'))
    end
    local divisions = options.divisions
    if divisions ~= nil and (positive(divisions, 'divisions', false) ~= math.floor(divisions)) then
        raise(std.ValueError('Slider.divisions must be a positive integer'))
    end
    local active = color(options.active_color or Color.rgba255(70, 150, 240), 'active_color')
    return {
        key = options.key, min = lower, max = upper, value = value, divisions = divisions,
        secondary_track_value = secondary,
        on_changed = callback(options.on_changed, 'on_changed'),
        on_change_start = callback(options.on_change_start, 'on_change_start'),
        on_change_end = callback(options.on_change_end, 'on_change_end'),
        enabled = options.enabled ~= false,
        active_color = active,
        inactive_color = color(options.inactive_color or Color.rgba255(255, 255, 255, 60), 'inactive_color'),
        secondary_active_color = color(options.secondary_active_color or active:with_alpha(0.4),
            'secondary_active_color'),
        thumb_color = color(options.thumb_color or active, 'thumb_color'),
        disabled_active_color = color(options.disabled_active_color or Color.rgba255(255, 255, 255, 80),
            'disabled_active_color'),
        disabled_inactive_color = color(options.disabled_inactive_color or Color.rgba255(255, 255, 255, 30),
            'disabled_inactive_color'),
        disabled_thumb_color = color(options.disabled_thumb_color or Color.rgba255(255, 255, 255, 100),
            'disabled_thumb_color'),
        overlay_color = color(options.overlay_color or active:with_alpha(0.15), 'overlay_color'),
        height = positive(options.height == nil and 48 or options.height, 'height', false),
        track_height = positive(options.track_height == nil and 4 or options.track_height, 'track_height', false),
        track_inset = positive(options.track_inset == nil and 20 or options.track_inset, 'track_inset', true),
        thumb_radius = positive(options.thumb_radius == nil and 10 or options.thumb_radius, 'thumb_radius', true),
        overlay_radius = positive(options.overlay_radius == nil and 20 or options.overlay_radius, 'overlay_radius', true),
        hit_expand = positive(options.hit_expand or 0, 'hit_expand', true),
    }
end

local fields = {
    'min', 'max', 'value', 'divisions', 'secondary_track_value', 'on_changed', 'on_change_start',
    'on_change_end', 'enabled', 'active_color', 'inactive_color', 'secondary_active_color',
    'thumb_color', 'disabled_active_color', 'disabled_inactive_color', 'disabled_thumb_color',
    'overlay_color', 'height', 'track_height', 'track_inset', 'thumb_radius', 'overlay_radius', 'hit_expand',
}

---@class RenderSlider : RenderObject, _SliderOptions
---@field hovered boolean
---@field dragging boolean
---@field _last_fraction number?
---@field _last_sent_value number?
---@overload fun(options?: _SliderOptions): self
local RenderSlider = std.class.new('RenderSlider', RenderObject)

function RenderSlider:__init(options)
    RenderObject.__init(self)
    self.hovered = false
    self.dragging = false
    self:configure(options)
end

---@return boolean
function RenderSlider:is_interactive()
    return self.enabled == true and self.on_changed ~= nil and self.min < self.max
end

---@param options _SliderOptions?
function RenderSlider:configure(options)
    local config = M.normalize(options)
    local was_interactive = self:is_interactive()
    if self.dragging and (config.enabled == false or config.on_changed == nil or config.min == config.max) then
        self:_end_interaction(true)
    end
    local layout_changed = self.height ~= config.height
    local input_changed = self.hit_expand ~= config.hit_expand or self.track_inset ~= config.track_inset
    local changed = false
    for _, name in ipairs(fields) do
        if self[name] ~= config[name] then
            self[name] = config[name]
            changed = true
        end
    end
    if was_interactive ~= self:is_interactive() or input_changed then
        self:mark_needs_input()
    end
    if layout_changed then
        self:mark_needs_layout()
    elseif changed then
        self:mark_needs_paint()
    end
end

function RenderSlider:__perform_layout(constraints)
    local width = constraints.max_width < math.huge and constraints.max_width or 144 + self.track_inset * 2
    self.size = constraints:constrain_size(Size(width, self.height))
end

---@return Rect
function RenderSlider:track_rect()
    local inset = math.min(self.track_inset, self.size.width / 2)
    local height = math.min(self.track_height, self.size.height)
    return Rect.from_ltwh(inset, (self.size.height - height) / 2, self.size.width - inset * 2, height)
end

---@param fraction number
---@return number
function RenderSlider:_value_at(fraction)
    fraction = math.max(0, math.min(1, fraction))
    if self.divisions then
        fraction = math.floor(fraction * self.divisions + 0.5) / self.divisions
    end
    return self.min + fraction * (self.max - self.min)
end

---@param value number
---@return number
function RenderSlider:_normalized(value)
    return self.max > self.min and (value - self.min) / (self.max - self.min) or 0
end

---@param point Offset?
---@return number?
function RenderSlider:_fraction(point)
    local track = self:track_rect()
    if point == nil or track:width() <= 0 then
        return nil
    end
    return math.max(0, math.min(1, (point.x - track.left) / track:width()))
end

---@param value number
function RenderSlider:set_value(value)
    finite(value, 'value')
    if value < self.min or value > self.max then
        raise(std.ValueError('Slider.value must be between min and max'))
    end
    if self.value ~= value then
        self.value = value
        self:mark_needs_paint()
    end
end

function RenderSlider:__paint(canvas, offset)
    local track = self:track_rect()
    local interactive = self:is_interactive()
    local active = interactive and self.active_color or self.disabled_active_color
    local inactive = interactive and self.inactive_color or self.disabled_inactive_color
    local thumb = interactive and self.thumb_color or self.disabled_thumb_color
    local fraction = self:_normalized(self:_value_at(self:_normalized(self.value)))
    local center_x = offset.x + track.left + fraction * track:width()
    local center_y = offset.y + self.size.height / 2
    local function segment(left, right, paint_color)
        if right > left then
            canvas:draw_rrect(Rect.from_ltwh(offset.x + left, offset.y + track.top,
                right - left, track:height()), track:height() / 2, Paint(paint_color))
        end
    end
    segment(track.left, track.right, inactive)
    if self.secondary_track_value and self.secondary_track_value > self.value then
        segment(track.left, track.left + track:width() * self:_normalized(self.secondary_track_value),
            interactive and self.secondary_active_color or self.disabled_active_color)
    end
    segment(track.left, center_x - offset.x, active)
    if self.divisions and track:width() / self.divisions >= 4 then
        for index = 0, self.divisions do
            local x = offset.x + track.left + track:width() * index / self.divisions
            canvas:draw_rrect(Rect.from_ltwh(x - 1, center_y - 1, 2, 2), 1, Paint(inactive))
        end
    end
    local function circle(radius, paint_color)
        if radius > 0 then
            canvas:draw_rrect(Rect.from_ltwh(center_x - radius, center_y - radius,
                radius * 2, radius * 2), radius, Paint(paint_color))
        end
    end
    if interactive and (self.hovered or self.dragging) then
        circle(self.overlay_radius, self.overlay_color)
    end
    circle(self.thumb_radius, thumb)
end

function RenderSlider:__hit_test_bounds(point)
    local expand = self.hit_expand
    return point.x >= -expand and point.y >= -expand
        and point.x < self.size.width + expand and point.y < self.size.height + expand
end

function RenderSlider:input_region_rect()
    local expand = self.hit_expand
    return Rect(-expand, -expand, self.size.width + expand, self.size.height + expand)
end

function RenderSlider:wants_pointer(event)
    return self:is_interactive() and (event == 'down' or event == 'up' or event == 'move')
end

-- Protected lifecycle hooks let Timeline add seek phases without duplicating capture.
function RenderSlider:__interaction_start(value)
    if self.on_change_start then
        self.on_change_start(self:_value_at(self:_normalized(self.value)))
    end
    self:__interaction_update(value)
end

function RenderSlider:__interaction_update(value)
    if value ~= self._last_sent_value then
        self._last_sent_value = value
        if value ~= self.value and self.on_changed then
            self.on_changed(value)
        end
    end
end

function RenderSlider:__interaction_end(value, _cancelled)
    if self.on_change_end then
        self.on_change_end(value)
    end
end

function RenderSlider:_end_interaction(cancelled)
    if not self.dragging then
        return
    end
    local value = self:_value_at(self._last_fraction or self:_normalized(self.value))
    self.dragging = false
    self._last_fraction = nil
    self._last_sent_value = nil
    self:__interaction_end(value, cancelled)
    self:mark_needs_paint()
end

function RenderSlider:on_pointer(event, point, data)
    if event == 'cancel' then
        self:_end_interaction(true)
        return false
    end
    if not self:is_interactive() then
        return false
    end
    if event == 'enter' or event == 'leave' then
        self.hovered = event == 'enter'
        self:mark_needs_paint()
    elseif event == 'down' and (data == nil or data == 'left') then
        local fraction = self:_fraction(point)
        if fraction == nil or self.dragging then
            return false
        end
        self.dragging = true
        self.hovered = true
        self._last_fraction = fraction
        self._last_sent_value = nil
        self:__interaction_start(self:_value_at(fraction))
        self:mark_needs_paint()
        return true
    elseif event == 'move' and self.dragging then
        local fraction = self:_fraction(point)
        if fraction ~= nil then
            self._last_fraction = fraction
            self:__interaction_update(self:_value_at(fraction))
        end
    elseif event == 'up' and (data == nil or data == 'left') and self.dragging then
        self:_end_interaction(false)
        return true
    end
    return false
end

M.RenderSlider = RenderSlider

return M
