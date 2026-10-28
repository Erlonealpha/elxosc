-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- A fixed-layout, paint-only progress/seek bar.  Progress and buffered range
-- changes do not rebuild or relayout the player; pointer handling remains on
-- the persistent RenderObject so its input region and capture are stable.

local std = require 'elxlibs.std'
local geometry = require 'foundation.geometry'
local color_mod = require 'foundation.color'
local paint_mod = require 'painting.paint'
local render_object = require 'render.render_object'

local Rect = geometry.Rect
local Size = geometry.Size
local Color = color_mod.Color
local Paint = paint_mod.Paint
local RenderObject = render_object.RenderObject
local raise = std.raise
local huge = math.huge
local min = math.min
local max = math.max

local M = {}

local function is_finite(value)
    return type(value) == 'number'
        and value == value
        and value ~= huge
        and value ~= -huge
end

local function validate_fraction(value, name)
    if not is_finite(value) or value < 0 or value > 1 then
        raise(std.ValueError(name .. ' must be between 0 and 1'))
    end
    return value
end

local function validate_color(value, name)
    if not std.isinstance(value, Color) then
        raise(std.TypeError(name .. ' must be a Color'))
    end
    return value
end

local function validate_callback(value, name)
    if value ~= nil and type(value) ~= 'function' then
        raise(std.TypeError(name .. ' must be a function'))
    end
    return value
end

---@class _RenderProgressBarOptions
---@field progress number? 0..1
---@field buffered number? 0..1
---@field track_color Color?
---@field buffered_color Color?
---@field progress_color Color?
---@field handle_color Color?
---@field height number? logical layout height
---@field handle_size number? 0..1 ratio of the bar height
---@field on_seek fun(fraction: number, phase: 'start'|'update'|'end')?
---@field enabled boolean?

---@class RenderProgressBar : RenderObject
---@field progress number
---@field buffered number
---@field track_color Color
---@field buffered_color Color
---@field progress_color Color
---@field handle_color Color
---@field height number
---@field handle_size number
---@field on_seek fun(fraction: number, phase: 'start'|'update'|'end')?
---@field enabled boolean
---@field hovered boolean
---@field dragging boolean
---@field _last_fraction number?
---@overload fun(options?: _RenderProgressBarOptions): self
local RenderProgressBar = std.class.new('RenderProgressBar', { RenderObject })

function RenderProgressBar:__init(options)
    RenderObject.__init(self)
    options = options or {}
    self.progress = validate_fraction(options.progress or 0, 'RenderProgressBar.progress')
    self.buffered = validate_fraction(options.buffered or 0, 'RenderProgressBar.buffered')
    self.track_color = validate_color(
        options.track_color or Color.rgba255(255, 255, 255, 45),
        'RenderProgressBar.track_color')
    self.buffered_color = validate_color(
        options.buffered_color or Color.rgba255(255, 255, 255, 90),
        'RenderProgressBar.buffered_color')
    self.progress_color = validate_color(
        options.progress_color or Color.rgba255(70, 150, 240),
        'RenderProgressBar.progress_color')
    self.handle_color = validate_color(
        options.handle_color or self.progress_color,
        'RenderProgressBar.handle_color')
    self.height = options.height == nil and 14 or options.height
    if not is_finite(self.height) or self.height <= 0 then
        raise(std.ValueError('RenderProgressBar.height must be a positive finite number'))
    end
    self.handle_size = options.handle_size == nil and 0.8 or options.handle_size
    validate_fraction(self.handle_size, 'RenderProgressBar.handle_size')
    self.on_seek = validate_callback(options.on_seek, 'RenderProgressBar.on_seek')
    self.enabled = options.enabled ~= false
    self.hovered = false
    self.dragging = false
    self._last_fraction = nil
end

function RenderProgressBar:__perform_layout(constraints)
    local width = constraints.max_width < huge and constraints.max_width
        or constraints.min_width
    self.size = constraints:constrain_size(Size(width, self.height))
end

---@param progress number
function RenderProgressBar:set_progress(progress)
    progress = validate_fraction(progress, 'RenderProgressBar.progress')
    if self.progress == progress then
        return
    end
    self.progress = progress
    self:mark_needs_paint()
end

---@param buffered number
function RenderProgressBar:set_buffered(buffered)
    buffered = validate_fraction(buffered, 'RenderProgressBar.buffered')
    if self.buffered == buffered then
        return
    end
    self.buffered = buffered
    self:mark_needs_paint()
end

---@param color Color
function RenderProgressBar:set_track_color(color)
    color = validate_color(color, 'RenderProgressBar.track_color')
    if self.track_color == color then
        return
    end
    self.track_color = color
    self:mark_needs_paint()
end

---@param color Color
function RenderProgressBar:set_buffered_color(color)
    color = validate_color(color, 'RenderProgressBar.buffered_color')
    if self.buffered_color == color then
        return
    end
    self.buffered_color = color
    self:mark_needs_paint()
end

---@param color Color
function RenderProgressBar:set_progress_color(color)
    color = validate_color(color, 'RenderProgressBar.progress_color')
    if self.progress_color == color then
        return
    end
    self.progress_color = color
    self:mark_needs_paint()
end

---@param color Color
function RenderProgressBar:set_handle_color(color)
    color = validate_color(color, 'RenderProgressBar.handle_color')
    if self.handle_color == color then
        return
    end
    self.handle_color = color
    self:mark_needs_paint()
end

---@param height number
function RenderProgressBar:set_height(height)
    if not is_finite(height) or height <= 0 then
        raise(std.ValueError('RenderProgressBar.height must be a positive finite number'))
    end
    if self.height == height then
        return
    end
    self.height = height
    self:mark_needs_layout()
end

---@param handle_size number
function RenderProgressBar:set_handle_size(handle_size)
    handle_size = validate_fraction(handle_size, 'RenderProgressBar.handle_size')
    if self.handle_size == handle_size then
        return
    end
    self.handle_size = handle_size
    self:mark_needs_paint()
end

---@param callback fun(fraction: number, phase: 'start'|'update'|'end')?
function RenderProgressBar:set_on_seek(callback)
    callback = validate_callback(callback, 'RenderProgressBar.on_seek')
    local old_wants = self.on_seek ~= nil and self.enabled
    local new_wants = callback ~= nil and self.enabled
    self.on_seek = callback
    if old_wants ~= new_wants then
        self:mark_needs_input()
    end
end

---@param enabled boolean
function RenderProgressBar:set_enabled(enabled)
    if type(enabled) ~= 'boolean' then
        raise(std.TypeError('RenderProgressBar.enabled must be a boolean'))
    end
    if self.enabled == enabled then
        return
    end
    self.enabled = enabled
    self.dragging = false
    self:mark_needs_input()
    self:mark_needs_paint()
end

function RenderProgressBar:__paint(canvas, offset)
    local width, height = self.size.width, self.size.height
    if width <= 0 or height <= 0 then
        return
    end
    local track_height = min(4, max(2, height * 0.22))
    local top = (height - track_height) / 2
    local track = Rect(offset.x, offset.y + top, offset.x + width, offset.y + top + track_height)
    local radius = track_height / 2
    canvas:draw_rrect(track, radius, Paint(self.track_color))

    local buffered_width = width * self.buffered
    if buffered_width > 0 then
        canvas:draw_rrect(
            Rect(offset.x, offset.y + top, offset.x + buffered_width, offset.y + top + track_height),
            radius, Paint(self.buffered_color))
    end

    local progress_width = width * self.progress
    if progress_width > 0 then
        canvas:draw_rrect(
            Rect(offset.x, offset.y + top, offset.x + progress_width, offset.y + top + track_height),
            radius, Paint(self.progress_color))
    end

    local handle_radius = height * 0.45 * self.handle_size
    if handle_radius > 0 then
        local handle_x = offset.x + progress_width
        local handle_top = offset.y + height / 2 - handle_radius
        canvas:draw_rrect(
            Rect(handle_x - handle_radius, handle_top,
                handle_x + handle_radius, handle_top + handle_radius * 2),
            handle_radius, Paint(self.handle_color))
    end
end

---@param point Offset?
---@return number?
function RenderProgressBar:_fraction(point)
    if point == nil or self.size.width <= 0 then
        return nil
    end
    return min(1, max(0, point.x / self.size.width))
end

function RenderProgressBar:wants_pointer(event)
    if not self.enabled or self.on_seek == nil then
        return false
    end
    return event == 'down' or event == 'up' or event == 'move'
end

function RenderProgressBar:on_pointer(event, point, data)
    if not self.enabled or self.on_seek == nil then
        return false
    end
    if (event == 'down' or event == 'up') and data ~= nil and data ~= 'left' then
        return false
    end
    if event == 'enter' then
        if not self.hovered then
            self.hovered = true
            self:mark_needs_paint()
        end
        return false
    elseif event == 'leave' then
        if self.hovered and not self.dragging then
            self.hovered = false
            self:mark_needs_paint()
        end
        return false
    elseif event == 'down' then
        local fraction = self:_fraction(point)
        if fraction == nil then
            return false
        end
        self.dragging = true
        self.hovered = true
        self._last_fraction = fraction
        self.on_seek(fraction, 'start')
        self:mark_needs_paint()
        return true
    elseif event == 'move' then
        local fraction = self:_fraction(point)
        if self.dragging and fraction ~= nil then
            self._last_fraction = fraction
            self.on_seek(fraction, 'update')
        end
        return false
    elseif event == 'up' then
        local fraction = self:_fraction(point)
        self.dragging = false
        fraction = fraction or self._last_fraction
        if fraction ~= nil then
            self.on_seek(fraction, 'end')
        end
        self._last_fraction = nil
        self:mark_needs_paint()
        return true
    elseif event == 'cancel' then
        self.dragging = false
        self._last_fraction = nil
        self:mark_needs_paint()
    end
    return false
end

M.RenderProgressBar = RenderProgressBar

return M
