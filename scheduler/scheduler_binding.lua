-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Instance-scoped binding facade for the host-neutral Scheduler.

local std = require 'elxlibs.std'
local binding_base = require 'foundation.binding_base'

local BindingBase = binding_base.BindingBase

local M = {}

---@class SchedulerBinding : std.object
---@field scheduler Scheduler?
---@overload fun(scheduler: Scheduler?): self
local SchedulerBinding = std.class.new('SchedulerBinding', { BindingBase })

function SchedulerBinding:__init(scheduler)
    ---@diagnostic disable-next-line: param-type-mismatch, generic-constraint-mismatch
    std.super(SchedulerBinding, self, BindingBase).__init(self)
    self.scheduler = scheduler
end

---@param time number
function SchedulerBinding:handle_frame(time)
    self:assert_alive()
    if self.scheduler and self.scheduler._handle_frame then
        self.scheduler:_handle_frame(time)
    end
end

function SchedulerBinding:dispose()
    if self._disposed then
        return false
    end
    if self.scheduler then
        self.scheduler:dispose()
        self.scheduler = nil
    end
    return BindingBase.dispose(self)
end

M.SchedulerBinding = SchedulerBinding

return M
