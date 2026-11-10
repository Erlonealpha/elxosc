-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- A fixed-layout media Timeline over the standard Slider. Progress and buffered range
-- changes do not rebuild or relayout the player; pointer handling remains on
-- the persistent RenderObject so its input region and capture are stable.

local std = require 'elxlibs.std'
local geometry = require 'foundation.geometry'
local color_mod = require 'foundation.color'
local paint_mod = require 'painting.paint'
local slider_mod = require 'render.slider'

local Rect = geometry.Rect
local Size = geometry.Size
local Color = color_mod.Color
local Paint = paint_mod.Paint
local RenderSlider = slider_mod.RenderSlider
local raise = std.raise
local huge = math.huge
local min = math.min
local max = math.max

---@class elxosc.render.timeline
local M = {}

---@alias TimelinePhase
--- | 'start'
--- | 'update'
--- | 'end'
--- | 'cancel'

---@alias SeekMode
--- | 'keyframe'
--- | 'exact'

---@alias TimelineMarkerStyle
--- | 'triangle'
--- | 'bar'
--- | 'single-bar'
--- | 'gap'

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

---@param value number
---@param name string
---@return number
local function validate_non_negative(value, name)
    if not is_finite(value) or value < 0 then
        raise(std.ValueError(name .. ' must be a finite non-negative number'))
    end
    return value
end

---@param value string
---@return string
local function validate_marker_style(value)
    if value ~= 'triangle' and value ~= 'bar' and value ~= 'single-bar' and value ~= 'gap' then
        raise(std.ValueError(
            'RenderTimeline.marker_style must be triangle, bar, single-bar or gap'))
    end
    return value
end

---@param value string
---@return string
local function validate_seek_mode(value)
    if value ~= 'keyframe' and value ~= 'exact' then
        raise(std.ValueError('RenderTimeline.seek_mode must be keyframe or exact'))
    end
    return value
end

---@param list table?
---@param name string
---@return table
local function copy_markers(list, name)
    if list == nil then
        return {}
    end
    if type(list) ~= 'table' then
        raise(std.TypeError(name .. ' must be a table'))
    end
    local copy = {}
    for index, marker in ipairs(list) do
        if type(marker) ~= 'table' then
            raise(std.TypeError(name .. ' entries must be tables'))
        end
        local fraction = marker.fraction
        if fraction == nil then
            fraction = marker.position
        end
        copy[index] = {
            fraction = validate_fraction(fraction or 0, name .. '[' .. index .. '].fraction'),
            current = marker.current == true,
        }
    end
    return copy
end

---@param list table?
---@return table
local function copy_ranges(list)
    if list == nil then
        return {}
    end
    if type(list) ~= 'table' then
        raise(std.TypeError('RenderTimeline.ranges must be a table'))
    end
    local copy = {}
    for index, range in ipairs(list) do
        if type(range) ~= 'table' then
            raise(std.TypeError('RenderTimeline.ranges entries must be tables'))
        end
        local start = range.start or range[1] or 0
        local finish = range['end'] or range.finish or range[2] or 0
        copy[index] = {
            start = validate_fraction(start, 'RenderTimeline.ranges[' .. index .. '].start'),
            ['end'] = validate_fraction(finish, 'RenderTimeline.ranges[' .. index .. '].end'),
        }
        if range.color ~= nil then
            copy[index].color = validate_color(
                range.color, 'RenderTimeline.ranges[' .. index .. '].color')
        end
        if copy[index]['end'] < copy[index].start then
            copy[index].start, copy[index]['end'] = copy[index]['end'], copy[index].start
        end
    end
    return copy
end

---@class _RenderTimelineOptions
---@field progress number? 0..1
---@field buffered number? 0..1
---@field track_color Color?
---@field buffered_color Color?
---@field progress_color Color?
---@field handle_color Color?
---@field hover_track_color Color?
---@field hover_buffered_color Color?
---@field hover_progress_color Color?
---@field hover_handle_color Color?
---@field height number? logical layout height
---@field handle_size number? 0..1 ratio of the bar height
---@field hover_handle_size number? 0..1 ratio of the bar height
---@field hover_expand number? extra input area in every direction
---@field range_expand number? horizontal cache-range expansion in px
---@field markers table? chapter marker fractions
---@field ranges table? seekable fractions
---@field marker_color Color?
---@field current_marker_color Color?
---@field range_color Color?
---@field marker_style TimelineMarkerStyle?
---@field on_seek fun(fraction: number, phase: TimelinePhase, mode: SeekMode)?
---@field on_context_seek fun(fraction: number)? right-click chapter callback
---@field on_wheel fun(delta: number)? wheel callback
---@field enabled boolean?

---@class RenderTimeline : RenderSlider
---@field progress number
---@field buffered number
---@field track_color Color
---@field buffered_color Color
---@field progress_color Color
---@field handle_color Color
---@field hover_track_color Color?
---@field hover_buffered_color Color?
---@field hover_progress_color Color?
---@field hover_handle_color Color?
---@field height number
---@field handle_size number
---@field hover_handle_size number
---@field hover_expand number
---@field range_expand number
---@field seek_mode SeekMode
---@field markers table[]
---@field ranges table[]
---@field marker_color Color
---@field current_marker_color Color
---@field range_color Color
---@field marker_style TimelineMarkerStyle
---@field on_seek fun(fraction: number, phase: TimelinePhase, mode: SeekMode)?
---@field on_context_seek fun(fraction: number)?
---@field on_wheel fun(delta: number)?
---@field enabled boolean
---@field hovered boolean
---@field dragging boolean
---@field _last_fraction number?
---@field _last_sent_fraction number?
---@field _seek_mode SeekMode
---@field _pending_seek_mode SeekMode?
---@overload fun(options?: _RenderTimelineOptions): self
local RenderTimeline = std.class.new('RenderTimeline', RenderSlider)

function RenderTimeline:__init(options)
    RenderSlider.__init(self, { value = 0, min = 0, max = 1, track_inset = 0 })
    options = options or {}
    self.progress = validate_fraction(options.progress or 0, 'RenderTimeline.progress')
    self.buffered = validate_fraction(options.buffered or 0, 'RenderTimeline.buffered')
    self.track_color = validate_color(
        options.track_color or Color.rgba255(255, 255, 255, 45),
        'RenderTimeline.track_color')
    self.buffered_color = validate_color(
        options.buffered_color or Color.rgba255(255, 255, 255, 90),
        'RenderTimeline.buffered_color')
    self.progress_color = validate_color(
        options.progress_color or Color.rgba255(70, 150, 240),
        'RenderTimeline.progress_color')
    self.handle_color = validate_color(
        options.handle_color or self.progress_color,
        'RenderTimeline.handle_color')
    self.hover_track_color = options.hover_track_color
        and validate_color(options.hover_track_color, 'RenderTimeline.hover_track_color') or nil
    self.hover_buffered_color = options.hover_buffered_color
        and validate_color(options.hover_buffered_color, 'RenderTimeline.hover_buffered_color') or nil
    self.hover_progress_color = options.hover_progress_color
        and validate_color(options.hover_progress_color, 'RenderTimeline.hover_progress_color') or nil
    self.hover_handle_color = options.hover_handle_color
        and validate_color(options.hover_handle_color, 'RenderTimeline.hover_handle_color') or nil
    self.height = options.height == nil and 14 or options.height
    if not is_finite(self.height) or self.height <= 0 then
        raise(std.ValueError('RenderTimeline.height must be a positive finite number'))
    end
    self.handle_size = options.handle_size == nil and 0.8 or options.handle_size
    validate_fraction(self.handle_size, 'RenderTimeline.handle_size')
    self.hover_handle_size = options.hover_handle_size == nil
        and self.handle_size or options.hover_handle_size
    validate_fraction(self.hover_handle_size, 'RenderTimeline.hover_handle_size')
    self.hover_expand = options.hover_expand == nil and 0 or options.hover_expand
    self.hit_expand = self.hover_expand
    self.hover_expand = validate_non_negative(self.hover_expand, 'RenderTimeline.hover_expand')
    self.range_expand = options.range_expand == nil and 0 or options.range_expand
    self.range_expand = validate_non_negative(self.range_expand, 'RenderTimeline.range_expand')
    self.seek_mode = validate_seek_mode(options.seek_mode or 'keyframe')
    self.value = self.progress
    self.markers = copy_markers(options.markers, 'RenderTimeline.markers')
    self.ranges = copy_ranges(options.ranges)
    self.marker_color = validate_color(
        options.marker_color or self.progress_color, 'RenderTimeline.marker_color')
    self.current_marker_color = validate_color(
        options.current_marker_color or self.marker_color,
        'RenderTimeline.current_marker_color')
    self.range_color = validate_color(
        options.range_color or self.buffered_color, 'RenderTimeline.range_color')
    self.marker_style = validate_marker_style(options.marker_style or 'bar')
    self.on_seek = validate_callback(options.on_seek, 'RenderTimeline.on_seek')
    self.on_context_seek = validate_callback(
        options.on_context_seek, 'RenderTimeline.on_context_seek')
    self.on_wheel = validate_callback(options.on_wheel, 'RenderTimeline.on_wheel')
    self.enabled = options.enabled ~= false
    self.hovered = false
    self.dragging = false
    self._last_fraction = nil
    self._last_sent_fraction = nil
    self._seek_mode = 'keyframe'
    self._pending_seek_mode = nil
end

---@param seek_mode SeekMode
function RenderTimeline:set_seek_mode(seek_mode)
    seek_mode = validate_seek_mode(seek_mode)
    if self.seek_mode == seek_mode then
        return
    end
    self.seek_mode = seek_mode
end

function RenderTimeline:__perform_layout(constraints)
    local width = constraints.max_width < huge and constraints.max_width
        or constraints.min_width
    self.size = constraints:constrain_size(Size(width, self.height))
end

---@param progress number
function RenderTimeline:set_progress(progress)
    progress = validate_fraction(progress, 'RenderTimeline.progress')
    if self.progress == progress then
        return
    end
    self.progress = progress
    self.value = progress
    self:mark_needs_paint()
end

---@param value number
function RenderTimeline:set_value(value)
    self:set_progress(value)
end

---@param buffered number
function RenderTimeline:set_buffered(buffered)
    buffered = validate_fraction(buffered, 'RenderTimeline.buffered')
    if self.buffered == buffered then
        return
    end
    self.buffered = buffered
    self:mark_needs_paint()
end

---@param color Color
function RenderTimeline:set_track_color(color)
    color = validate_color(color, 'RenderTimeline.track_color')
    if self.track_color == color then
        return
    end
    self.track_color = color
    self:mark_needs_paint()
end

---@param color Color
function RenderTimeline:set_buffered_color(color)
    color = validate_color(color, 'RenderTimeline.buffered_color')
    if self.buffered_color == color then
        return
    end
    self.buffered_color = color
    self:mark_needs_paint()
end

---@param color Color
function RenderTimeline:set_progress_color(color)
    color = validate_color(color, 'RenderTimeline.progress_color')
    if self.progress_color == color then
        return
    end
    self.progress_color = color
    self:mark_needs_paint()
end

---@param color Color
function RenderTimeline:set_handle_color(color)
    color = validate_color(color, 'RenderTimeline.handle_color')
    if self.handle_color == color then
        return
    end
    self.handle_color = color
    self:mark_needs_paint()
end

---@param color Color?
function RenderTimeline:set_hover_track_color(color)
    if color ~= nil then
        color = validate_color(color, 'RenderTimeline.hover_track_color')
    end
    if self.hover_track_color == color then
        return
    end
    self.hover_track_color = color
    self:mark_needs_paint()
end

---@param color Color?
function RenderTimeline:set_hover_buffered_color(color)
    if color ~= nil then
        color = validate_color(color, 'RenderTimeline.hover_buffered_color')
    end
    if self.hover_buffered_color == color then
        return
    end
    self.hover_buffered_color = color
    self:mark_needs_paint()
end

---@param color Color?
function RenderTimeline:set_hover_progress_color(color)
    if color ~= nil then
        color = validate_color(color, 'RenderTimeline.hover_progress_color')
    end
    if self.hover_progress_color == color then
        return
    end
    self.hover_progress_color = color
    self:mark_needs_paint()
end

---@param color Color?
function RenderTimeline:set_hover_handle_color(color)
    if color ~= nil then
        color = validate_color(color, 'RenderTimeline.hover_handle_color')
    end
    if self.hover_handle_color == color then
        return
    end
    self.hover_handle_color = color
    self:mark_needs_paint()
end

---@param height number
function RenderTimeline:set_height(height)
    if not is_finite(height) or height <= 0 then
        raise(std.ValueError('RenderTimeline.height must be a positive finite number'))
    end
    if self.height == height then
        return
    end
    self.height = height
    self:mark_needs_layout()
end

---@param handle_size number
function RenderTimeline:set_handle_size(handle_size)
    handle_size = validate_fraction(handle_size, 'RenderTimeline.handle_size')
    if self.handle_size == handle_size then
        return
    end
    self.handle_size = handle_size
    self:mark_needs_paint()
end

---@param handle_size number
function RenderTimeline:set_hover_handle_size(handle_size)
    handle_size = validate_fraction(handle_size, 'RenderTimeline.hover_handle_size')
    if self.hover_handle_size == handle_size then
        return
    end
    self.hover_handle_size = handle_size
    self:mark_needs_paint()
end

---@param expand number
function RenderTimeline:set_hover_expand(expand)
    expand = validate_non_negative(expand, 'RenderTimeline.hover_expand')
    if self.hover_expand == expand then
        return
    end
    self.hover_expand = expand
    self.hit_expand = expand
    self:mark_needs_input()
    self:mark_needs_paint()
end

---@param expand number
function RenderTimeline:set_range_expand(expand)
    expand = validate_non_negative(expand, 'RenderTimeline.range_expand')
    if self.range_expand == expand then
        return
    end
    self.range_expand = expand
    self:mark_needs_paint()
end

---@param markers table?
function RenderTimeline:set_markers(markers)
    self.markers = copy_markers(markers, 'RenderTimeline.markers')
    self:mark_needs_paint()
end

---@param ranges table?
function RenderTimeline:set_ranges(ranges)
    self.ranges = copy_ranges(ranges)
    self:mark_needs_paint()
end

---@param marker_style TimelineMarkerStyle
function RenderTimeline:set_marker_style(marker_style)
    marker_style = validate_marker_style(marker_style)
    if self.marker_style == marker_style then
        return
    end
    self.marker_style = marker_style
    self:mark_needs_paint()
end

---@param color Color
function RenderTimeline:set_marker_color(color)
    color = validate_color(color, 'RenderTimeline.marker_color')
    if self.marker_color == color then
        return
    end
    self.marker_color = color
    self:mark_needs_paint()
end

---@param color Color
function RenderTimeline:set_current_marker_color(color)
    color = validate_color(color, 'RenderTimeline.current_marker_color')
    if self.current_marker_color == color then
        return
    end
    self.current_marker_color = color
    self:mark_needs_paint()
end

---@param color Color
function RenderTimeline:set_range_color(color)
    color = validate_color(color, 'RenderTimeline.range_color')
    if self.range_color == color then
        return
    end
    self.range_color = color
    self:mark_needs_paint()
end

---@param callback fun(fraction: number, phase: TimelinePhase, mode: SeekMode)?
function RenderTimeline:set_on_seek(callback)
    callback = validate_callback(callback, 'RenderTimeline.on_seek')
    if callback == nil and self.dragging then
        self:_end_interaction(true)
    end
    local old_wants = self.on_seek ~= nil and self.enabled
    local new_wants = callback ~= nil and self.enabled
    self.on_seek = callback
    if old_wants ~= new_wants then
        self:mark_needs_input()
    end
end

---@param callback fun(fraction: number)?
function RenderTimeline:set_on_context_seek(callback)
    callback = validate_callback(callback, 'RenderTimeline.on_context_seek')
    local old_wants = self.on_context_seek ~= nil and self.enabled
    local new_wants = callback ~= nil and self.enabled
    self.on_context_seek = callback
    if old_wants ~= new_wants then
        self:mark_needs_input()
    end
end

---@param callback fun(delta: number)?
function RenderTimeline:set_on_wheel(callback)
    callback = validate_callback(callback, 'RenderTimeline.on_wheel')
    local old_wants = self.on_wheel ~= nil and self.enabled
    local new_wants = callback ~= nil and self.enabled
    self.on_wheel = callback
    if old_wants ~= new_wants then
        self:mark_needs_input()
    end
end

---@param enabled boolean
function RenderTimeline:set_enabled(enabled)
    if type(enabled) ~= 'boolean' then
        raise(std.TypeError('RenderTimeline.enabled must be a boolean'))
    end
    if self.enabled == enabled then
        return
    end
    if not enabled then
        self:_end_interaction(true)
    end
    self.enabled = enabled
    self.dragging = false
    self:mark_needs_input()
    self:mark_needs_paint()
end

function RenderTimeline:__paint(canvas, offset)
    local width, height = self.size.width, self.size.height
    if width <= 0 or height <= 0 then
        return
    end
    local track_height = min(4, max(2, height * 0.22))
    local top = (height - track_height) / 2
    local radius = track_height / 2

    local gap_cuts = {}
    if self.marker_style == 'gap' then
        for _, marker in ipairs(self.markers) do
            -- The first chapter is the start edge, not a visible cut.
            if marker.fraction > 0 and marker.fraction < 1 then
                gap_cuts[#gap_cuts + 1] = width * marker.fraction
            end
        end
        table.sort(gap_cuts)
    end

    local function draw_bar(left, right, color)
        if right <= left then
            return
        end
        canvas:draw_rrect(
            Rect(offset.x + left, offset.y + top, offset.x + right,
                offset.y + top + track_height), radius, Paint(color))
    end

    local function draw_segmented(right, color)
        if #gap_cuts == 0 then
            draw_bar(0, right, color)
            return
        end
        local cursor = 0
        local gap_half = 1.5
        for _, cut in ipairs(gap_cuts) do
            if cut >= right then
                break
            end
            draw_bar(cursor, min(right, cut - gap_half), color)
            cursor = cut + gap_half
        end
        draw_bar(cursor, right, color)
    end

    local track_color = self.hovered and self.hover_track_color or nil
    track_color = track_color or self.track_color
    draw_segmented(width, track_color)

    local buffered_width = width * self.buffered
    if buffered_width > 0 then
        local buffered_color = self.hovered and self.hover_buffered_color or nil
        buffered_color = buffered_color or self.buffered_color
        draw_segmented(buffered_width, buffered_color)
    end

    local progress_width = width * self.progress
    if progress_width > 0 then
        local progress_color = self.hovered and self.hover_progress_color or nil
        progress_color = progress_color or self.progress_color
        draw_segmented(progress_width, progress_color)
    end

    -- ModernX paints seekable cache ranges over the played fill so the
    -- discontinuous cache state remains visible instead of being swallowed by
    -- the continuous buffered/progress primitives.
    for _, range in ipairs(self.ranges) do
        local range_left = max(0, width * range.start - self.range_expand)
        local range_right = min(width, width * range['end'] + self.range_expand)
        if range_right > range_left then
            draw_bar(range_left, range_right, range.color or self.range_color)
        end
    end

    if self.marker_style ~= 'gap' then
        for _, marker in ipairs(self.markers) do
            local marker_x = offset.x + width * marker.fraction
            local marker_color = marker.current and self.current_marker_color or self.marker_color
            local marker_paint = Paint(marker_color)
            if self.marker_style == 'triangle' then
                local marker_path = require('painting.path').Path()
                    :move_to(marker_x, offset.y + top - height * 0.25)
                    :line_to(marker_x - height * 0.3, offset.y + top)
                    :line_to(marker_x + height * 0.3, offset.y + top)
                    :close()
                canvas:draw_path(marker_path, marker_paint)
            elseif self.marker_style == 'single-bar' then
                canvas:draw_rect(
                    Rect(marker_x - 0.5, offset.y + top, marker_x + 0.5,
                        offset.y + top + track_height), marker_paint)
            else
                canvas:draw_rect(
                    Rect(marker_x - 1, offset.y + top - height * 0.2, marker_x + 1,
                        offset.y + top + track_height + height * 0.2), marker_paint)
            end
        end
    end

    local handle_size = self.hovered and self.hover_handle_size or self.handle_size
    local handle_color = self.hovered and self.hover_handle_color or nil
    handle_color = handle_color or self.handle_color
    local handle_radius = height * 0.45 * handle_size
    if handle_radius > 0 then
        local handle_x = offset.x + progress_width
        local handle_top = offset.y + height / 2 - handle_radius
        canvas:draw_rrect(
            Rect(handle_x - handle_radius, handle_top,
            handle_x + handle_radius, handle_top + handle_radius * 2),
            handle_radius, Paint(handle_color))
    end
end

---@param point Offset?
---@return number?
function RenderTimeline:_fraction(point)
    if point == nil or self.size.width <= 0 then
        return nil
    end
    return min(1, max(0, point.x / self.size.width))
end

---@param point Offset
---@return boolean
function RenderTimeline:__hit_test_bounds(point)
    local expand = self.hover_expand
    return point.x >= -expand and point.y >= -expand
        and point.x < self.size.width + expand and point.y < self.size.height + expand
end

---@return Rect
function RenderTimeline:input_region_rect()
    local expand = self.hover_expand
    return Rect(-expand, -expand,
        self.size.width + expand, self.size.height + expand)
end

function RenderTimeline:wants_pointer(event)
    if not self.enabled then
        return false
    end
    if event == 'wheel' then
        return self.on_wheel ~= nil
    end
    if event == 'move' then
        return self.on_seek ~= nil or self.on_context_seek ~= nil or self.on_wheel ~= nil
    end
    if event == 'down' or event == 'up' then
        return self.on_seek ~= nil or self.on_context_seek ~= nil
    end
    return false
end

---@param event PointerEvent
---@param point Offset?
---@return boolean|DispatchResult|nil
function RenderTimeline:on_pointer_event(event, point)
    if event.type == 'down' and (event.button == 'left' or event.data == 'left') then
        self._pending_seek_mode = event.modifiers and event.modifiers.shift
            and 'exact' or self.seek_mode
    end
    return RenderSlider.on_pointer_event(self, event, point)
end

function RenderTimeline:is_interactive()
    return self.enabled == true and self.on_seek ~= nil
end

function RenderTimeline:__interaction_start(value)
    self._seek_mode = self._pending_seek_mode or self.seek_mode
    self._pending_seek_mode = nil
    self._last_sent_fraction = value
    if self.on_seek then
        self.on_seek(value, 'start', self._seek_mode)
    end
end

function RenderTimeline:__interaction_update(value)
    if self._last_sent_fraction ~= value and self.on_seek then
        self._last_sent_fraction = value
        self.on_seek(value, 'update', self._seek_mode)
    end
end

function RenderTimeline:__interaction_end(value, cancelled)
    self._last_sent_fraction = nil
    if self.on_seek then
        self.on_seek(value, cancelled and 'cancel' or 'end', self._seek_mode)
    end
end

function RenderTimeline:on_pointer(event, point, data)
    if not self.enabled then
        return false
    end
    if event == 'down' and data == 'right' and self.on_context_seek then
        local fraction = self:_fraction(point)
        if fraction ~= nil then
            self.on_context_seek(fraction)
            return true
        end
    elseif event == 'wheel' and self.on_wheel then
        local delta = type(data) == 'table' and data.y or data
        if type(delta) == 'number' and delta ~= 0 then
            self.on_wheel(delta)
            return true
        end
    elseif event == 'enter' or event == 'leave' then
        local hovered = event == 'enter' or self.dragging
        if self.hovered ~= hovered then
            self.hovered = hovered
            self:mark_needs_paint()
        end
        return false
    end
    return RenderSlider.on_pointer(self, event, point, data)
end

M.RenderTimeline = RenderTimeline

return M
