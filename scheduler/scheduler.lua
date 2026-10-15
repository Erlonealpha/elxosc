-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Frame pipeline driver (a trimmed `SchedulerBinding`).
--
-- One frame runs in two phases:
--   1. transient callbacks -- animations/tickers, given the elapsed seconds;
--   2. persistent callbacks -- build/layout/paint, given the elapsed seconds.
-- then every queued post-frame callback runs. Nothing is recomputed unless
-- something asked for a frame via `schedule_frame`, which is what keeps an
-- idle UI from re-emitting ASS on every host tick.

local std = require 'elxlibs.std'

local M = {}

---@param set table
---@return table
local function snapshot(set)
    local arr = {}
    local n = 0
    for cb in pairs(set) do
        n = n + 1
        arr[n] = cb
    end
    return arr
end

---@class Scheduler : std.object
---@field clock FrameClock
---@field _disposed boolean
---@overload fun(clock: FrameClock): self
local Scheduler = std.class.new('Scheduler', {})

function Scheduler:__init(clock)
    self.clock = clock
    ---@type table<fun(dt: number, time: number), true>
    self._transient = {}
    ---@type table<fun(dt: number, time: number), true>
    self._persistent = {}
    ---@type (fun())[]
    self._post_frame = {}
    self._scheduled = false
    self._last_time = nil
    self._disposed = false
    clock:set_handler(function(time)
        self:_handle_frame(time)
    end)
end

---@param cb fun(dt: number, time: number)
function Scheduler:add_transient(cb)
    if self._disposed then
        return
    end
    self._transient[cb] = true
end

---@param cb fun(dt: number, time: number)
function Scheduler:remove_transient(cb)
    self._transient[cb] = nil
end

---@param cb fun(dt: number, time: number)
function Scheduler:add_persistent(cb)
    if self._disposed then
        return
    end
    self._persistent[cb] = true
end

---@param cb fun(dt: number, time: number)
function Scheduler:remove_persistent(cb)
    self._persistent[cb] = nil
end

---@param cb fun()
function Scheduler:add_post_frame(cb)
    if self._disposed then
        return
    end
    local posts = self._post_frame
    posts[#posts + 1] = cb
end

---@return boolean
function Scheduler:is_frame_scheduled()
    return self._scheduled
end

--- Request a frame; repeated calls before the frame runs are coalesced.
function Scheduler:schedule_frame()
    if self._disposed then
        return
    end
    if not self._scheduled then
        self._scheduled = true
        self.clock:request_frame()
    end
end

---@param time number
function Scheduler:_handle_frame(time)
    if self._disposed then
        return
    end
    self._scheduled = false
    local last = self._last_time
    local dt = last and (time - last) or 0
    self._last_time = time

    for _, cb in ipairs(snapshot(self._transient)) do
        cb(dt, time)
    end
    for _, cb in ipairs(snapshot(self._persistent)) do
        cb(dt, time)
    end

    local posts = self._post_frame
    if #posts > 0 then
        self._post_frame = {}
        for _, cb in ipairs(posts) do
            cb()
        end
    end

    -- keep animating for as long as transient callbacks (tickers) are alive
    if next(self._transient) ~= nil then
        self:schedule_frame()
    end
end

--- Stop the frame pipeline and release all registered callbacks.
function Scheduler:dispose()
    if self._disposed then
        return false
    end
    self._disposed = true
    self._transient = {}
    self._persistent = {}
    self._post_frame = {}
    self._scheduled = false
    self.clock:set_handler(nil)
    return true
end

M.Scheduler = Scheduler

return M
