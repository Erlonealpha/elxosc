-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Host frame/timing source.
--
-- The framework never touches mpv's timers directly: the ASS backend drives
-- frames with `mp.add_timeout` + `osd-overlay`, a mpv.net backend can drive
-- them from a real render/vsync callback, and tests drive them from a manual
-- clock. Only `now` and `request_frame` are backend specific.

local std = require 'elxlibs.std'

local raise = std.raise

local M = {}

---@class FrameClock : std.object
---@field handler fun(time: number)?
---@field _disposed boolean
---@overload fun(): self
local FrameClock = std.class.new('FrameClock', {})

function FrameClock:__init()
    self.handler = nil
    self._disposed = false
end

--- Current time in seconds (monotonic where the host allows it).
---@return number
function FrameClock:now()
    raise(std.NotImplementedError('FrameClock:now must be implemented by a host backend'))
end

--- Ask the host to deliver exactly one frame. When it is due the host must
--- call `_emit`, which invokes the registered handler.
function FrameClock:request_frame()
    if self._disposed then
        return
    end
    raise(std.NotImplementedError('FrameClock:request_frame must be implemented by a host backend'))
end

--- Register the single frame handler (normally the Scheduler).
---@param handler fun(time: number)?
function FrameClock:set_handler(handler)
    if self._disposed then
        return
    end
    self.handler = handler
end

---@return boolean
function FrameClock:has_handler()
    return self.handler ~= nil
end

--- Called by the host when a requested frame is ready; `time` defaults to
--- `now()`.
---@param time number?
function FrameClock:_emit(time)
    if self._disposed then
        return
    end
    local handler = self.handler
    if handler then
        handler(time or self:now())
    end
end

--- Stop delivering frames and release the scheduler handler.
function FrameClock:dispose()
    self._disposed = true
    self.handler = nil
end

M.FrameClock = FrameClock

return M
