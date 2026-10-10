-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Per-frame time source for animations (Flutter's `Ticker`).
--
-- A ticker registers as a transient scheduler callback, so the scheduler keeps
-- requesting frames while it is active and goes idle as soon as every ticker
-- is stopped. `on_tick` receives the elapsed seconds since the previous frame
-- (0 on the very first tick).

local std = require 'elxlibs.std'

local M = {}

---@class Ticker : std.object
---@field scheduler Scheduler
---@field on_tick fun(dt: number)
---@overload fun(scheduler: Scheduler, on_tick: fun(dt: number)): Ticker
local Ticker = std.class.new('Ticker')

function Ticker:__init(scheduler, on_tick)
    self.scheduler = scheduler
    self.on_tick = on_tick
    self._active = false
    self._callback = function(dt)
        if self._active then
            self.on_tick(dt)
        end
    end
end

---@return boolean
function Ticker:is_active()
    return self._active
end

function Ticker:start()
    if self._active then
        return
    end
    self._active = true
    self.scheduler:add_transient(self._callback)
    self.scheduler:schedule_frame()
end

function Ticker:stop()
    if not self._active then
        return
    end
    self._active = false
    self.scheduler:remove_transient(self._callback)
end

M.Ticker = Ticker

return M
