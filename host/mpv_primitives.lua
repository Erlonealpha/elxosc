-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Small mpv-backed host primitives shared by the single App owner.
--
-- These objects deliberately do not know about App, WidgetBinding or input.  App
-- owns their lifecycle; this module only adapts the framework clock and canvas
-- output contracts to mpv.

local mp = require 'mp'

local std = require 'elxlibs.std'
local frame_clock = require 'scheduler.frame_clock'

local FrameClock = frame_clock.FrameClock
local math = math

local M = {}

--== frame clock ===========================================================

--- Drives frames from `mp.add_timeout`, one timer per requested frame, with
--- the same rate limiting uosc applies via `render_delay`.
---@class MpFrameClock : FrameClock
---@field delay number minimum seconds between frames
---@field _timer table?
---@field _last_frame number?
---@field _disposed boolean
---@overload fun(delay: number?): self
local MpFrameClock = std.class.new('MpFrameClock', { FrameClock })

function MpFrameClock:__init(delay)
    self.delay = delay or (1 / 60)
    self._timer = nil
    self._last_frame = nil
    self._disposed = false
end

function MpFrameClock:now()
    return mp.get_time()
end

---@param delay number
function MpFrameClock:set_delay(delay)
    self.delay = delay
end

function MpFrameClock:request_frame()
    if self._disposed then
        return
    end
    if self._timer then
        return
    end
    local last = self._last_frame
    local since = last and (mp.get_time() - last) or math.huge
    self._timer = mp.add_timeout(math.max(0, self.delay - since), function()
        self._timer = nil
        if self._disposed then
            return
        end
        self._last_frame = mp.get_time()
        self:_emit()
    end)
end

---@return boolean disposed
function MpFrameClock:dispose()
    if self._disposed then
        return false
    end
    self._disposed = true
    local timer = self._timer
    self._timer = nil
    if timer and timer.kill then
        timer:kill()
    end
    self.handler = nil
    return true
end

--== presenter =============================================================

--- Pushes the canvas as an `ass-events` overlay, skipping identical frames.
---@class AssPresenter : std.object
---@field overlay table
---@field _last_data string?
---@field _last_w number
---@field _last_h number
---@overload fun(z: number?): self
local AssPresenter = std.class.new('AssPresenter', {})

function AssPresenter:__init(z)
    self.overlay = mp.create_osd_overlay('ass-events')
    self.overlay.z = z or 2000
    self._last_data = nil
    self._last_w, self._last_h = -1, -1
end

---@param canvas AssCanvas
---@param width number
---@param height number
function AssPresenter:present(canvas, width, height)
    local res_x, res_y = math.floor(width), math.floor(height)
    local data = canvas:text()
    if data == self._last_data and res_x == self._last_w and res_y == self._last_h then
        return
    end
    self._last_data = data
    self._last_w, self._last_h = res_x, res_y
    self.overlay.res_x, self.overlay.res_y = res_x, res_y
    self.overlay.data = data
    self.overlay:update()
end

function AssPresenter:remove()
    self.overlay:remove()
end

M.MpFrameClock = MpFrameClock
M.AssPresenter = AssPresenter

return M
