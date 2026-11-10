-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Media timeline with chapters, cache ranges and seek-phase callbacks.

local std = require 'elxlibs.std'
local color_mod = require 'foundation.color'
local timeline_mod = require 'render.timeline'
local slider_mod = require 'widget.widgets.slider'

local RenderTimeline = timeline_mod.RenderTimeline
local Slider = slider_mod.Slider
local Color = color_mod.Color

---@class _TimelineAppearanceOptions
---@field track_color Color?
---@field buffered_color Color?
---@field progress_color Color?
---@field handle_color Color?
---@field hover_track_color Color?
---@field hover_buffered_color Color?
---@field hover_progress_color Color?
---@field hover_handle_color Color?
---@field height number?
---@field handle_size number?
---@field hover_handle_size number?
---@field hover_expand number?
---@field range_expand number?

---@class _TimelineOptions : _TimelineAppearanceOptions
---@field progress number?
---@field buffered number?
---@field seek_mode SeekMode?
---@field markers table?
---@field ranges table?
---@field marker_color Color?
---@field current_marker_color Color?
---@field range_color Color?
---@field marker_style TimelineMarkerStyle?
---@field on_seek fun(fraction: number, phase: TimelinePhase, mode: SeekMode)?
---@field on_context_seek fun(fraction: number)?
---@field on_wheel fun(delta: number)?
---@field enabled boolean?
---@field key any?

---@class Timeline : Slider
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
---@overload fun(options?: _TimelineOptions): self
local Timeline = std.class.new('Timeline', Slider)

function Timeline:__init(options)
    options = options or {}
    self.key = options.key
    self.progress = options.progress == nil and 0 or options.progress
    self.value = self.progress
    self.min = 0
    self.max = 1
    self.buffered = options.buffered == nil and 0 or options.buffered
    self.track_color = options.track_color or Color.rgba255(255, 255, 255, 45)
    self.buffered_color = options.buffered_color or Color.rgba255(255, 255, 255, 90)
    self.progress_color = options.progress_color or Color.rgba255(70, 150, 240)
    self.handle_color = options.handle_color or self.progress_color
    self.hover_track_color = options.hover_track_color
    self.hover_buffered_color = options.hover_buffered_color
    self.hover_progress_color = options.hover_progress_color
    self.hover_handle_color = options.hover_handle_color
    self.height = options.height == nil and 14 or options.height
    self.handle_size = options.handle_size == nil and 0.8 or options.handle_size
    self.hover_handle_size = options.hover_handle_size == nil
        and self.handle_size or options.hover_handle_size
    self.hover_expand = options.hover_expand == nil and 0 or options.hover_expand
    self.range_expand = options.range_expand == nil and 0 or options.range_expand
    self.seek_mode = options.seek_mode or 'keyframe'
    self.markers = options.markers
    self.ranges = options.ranges
    self.marker_color = options.marker_color or self.progress_color
    self.current_marker_color = options.current_marker_color or self.marker_color
    self.range_color = options.range_color or self.buffered_color
    self.marker_style = options.marker_style or 'bar'
    self.on_seek = options.on_seek
    self.on_context_seek = options.on_context_seek
    self.on_wheel = options.on_wheel
    self.enabled = options.enabled ~= false
end

function Timeline:create_render_object()
    return RenderTimeline({
        progress = self.progress,
        buffered = self.buffered,
        track_color = self.track_color,
        buffered_color = self.buffered_color,
        progress_color = self.progress_color,
        handle_color = self.handle_color,
        hover_track_color = self.hover_track_color,
        hover_buffered_color = self.hover_buffered_color,
        hover_progress_color = self.hover_progress_color,
        hover_handle_color = self.hover_handle_color,
        height = self.height,
        handle_size = self.handle_size,
        hover_handle_size = self.hover_handle_size,
        hover_expand = self.hover_expand,
        range_expand = self.range_expand,
        seek_mode = self.seek_mode,
        markers = self.markers,
        ranges = self.ranges,
        marker_color = self.marker_color,
        current_marker_color = self.current_marker_color,
        range_color = self.range_color,
        marker_style = self.marker_style,
        on_seek = self.on_seek,
        on_context_seek = self.on_context_seek,
        on_wheel = self.on_wheel,
        enabled = self.enabled,
    })
end

---@param render_object RenderTimeline
function Timeline:update_render_object(render_object)
    render_object:set_progress(self.progress)
    render_object:set_buffered(self.buffered)
    render_object:set_track_color(self.track_color)
    render_object:set_buffered_color(self.buffered_color)
    render_object:set_progress_color(self.progress_color)
    render_object:set_handle_color(self.handle_color)
    render_object:set_hover_track_color(self.hover_track_color)
    render_object:set_hover_buffered_color(self.hover_buffered_color)
    render_object:set_hover_progress_color(self.hover_progress_color)
    render_object:set_hover_handle_color(self.hover_handle_color)
    render_object:set_height(self.height)
    render_object:set_handle_size(self.handle_size)
    render_object:set_hover_handle_size(self.hover_handle_size)
    render_object:set_hover_expand(self.hover_expand)
    render_object:set_range_expand(self.range_expand)
    render_object:set_seek_mode(self.seek_mode)
    render_object:set_markers(self.markers)
    render_object:set_ranges(self.ranges)
    render_object:set_marker_color(self.marker_color)
    render_object:set_current_marker_color(self.current_marker_color)
    render_object:set_range_color(self.range_color)
    render_object:set_marker_style(self.marker_style)
    render_object:set_on_seek(self.on_seek)
    render_object:set_on_context_seek(self.on_context_seek)
    render_object:set_on_wheel(self.on_wheel)
    render_object:set_enabled(self.enabled)
end

---@class elxosc.widget.player.timeline
local M = { Timeline = Timeline }

return M
