-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Flutter-style SchedulerBinding role facade.  SchedulerBinding is a binding
-- capability of the one WidgetsBinding composition, not a second runtime
-- instance.  Per-tree Scheduler objects may still be injected by a host/test
-- owner scope when an isolated clock is required.

local M = {}

---@class SchedulerBindingRole
local SchedulerBinding = {}

function SchedulerBinding.ensure_initialized()
    local widgets_binding = require 'widget.binding'
    return widgets_binding.WidgetsBinding.ensure_initialized()
end

function SchedulerBinding.instance()
    local widgets_binding = require 'widget.binding'
    return widgets_binding.WidgetsBinding.instance()
end

---@param scheduler Scheduler
---@param time number
function SchedulerBinding.handle_frame(scheduler, time)
    if scheduler and scheduler._handle_frame then
        scheduler:_handle_frame(time)
    end
end

M.SchedulerBinding = SchedulerBinding

return M
