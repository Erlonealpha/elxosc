-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Widget front end for the fixed-layout player progress/seek bar.

local std = require 'elxlibs.std'
local color_mod = require 'foundation.color'
local progress_mod = require 'render.progress_bar'
local widget_mod = require 'widget.widget'

local RenderProgressBar = progress_mod.RenderProgressBar
local LeafRenderObjectWidget = widget_mod.LeafRenderObjectWidget
local Color = color_mod.Color

---@class _ProgressBarOptions
---@field progress number?
---@field buffered number?
---@field track_color Color?
---@field buffered_color Color?
---@field progress_color Color?
---@field handle_color Color?
---@field height number?
---@field handle_size number?
---@field on_seek fun(fraction: number, phase: 'start'|'update'|'end')?
---@field enabled boolean?
---@field key any?

---@class ProgressBar : LeafRenderObjectWidget
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
---@overload fun(options?: _ProgressBarOptions): self
local ProgressBar = std.class.new('ProgressBar', { LeafRenderObjectWidget })

function ProgressBar:__init(options)
    options = options or {}
    self.key = options.key
    self.progress = options.progress == nil and 0 or options.progress
    self.buffered = options.buffered == nil and 0 or options.buffered
    self.track_color = options.track_color or Color.rgba255(255, 255, 255, 45)
    self.buffered_color = options.buffered_color or Color.rgba255(255, 255, 255, 90)
    self.progress_color = options.progress_color or Color.rgba255(70, 150, 240)
    self.handle_color = options.handle_color or self.progress_color
    self.height = options.height == nil and 14 or options.height
    self.handle_size = options.handle_size == nil and 0.8 or options.handle_size
    self.on_seek = options.on_seek
    self.enabled = options.enabled ~= false
end

function ProgressBar:create_render_object()
    return RenderProgressBar({
        progress = self.progress,
        buffered = self.buffered,
        track_color = self.track_color,
        buffered_color = self.buffered_color,
        progress_color = self.progress_color,
        handle_color = self.handle_color,
        height = self.height,
        handle_size = self.handle_size,
        on_seek = self.on_seek,
        enabled = self.enabled,
    })
end

---@param render_object RenderProgressBar
function ProgressBar:update_render_object(render_object)
    render_object:set_progress(self.progress)
    render_object:set_buffered(self.buffered)
    render_object:set_track_color(self.track_color)
    render_object:set_buffered_color(self.buffered_color)
    render_object:set_progress_color(self.progress_color)
    render_object:set_handle_color(self.handle_color)
    render_object:set_height(self.height)
    render_object:set_handle_size(self.handle_size)
    render_object:set_on_seek(self.on_seek)
    render_object:set_enabled(self.enabled)
end

return { ProgressBar = ProgressBar, SeekBar = ProgressBar }
