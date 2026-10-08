-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Mutable state attached to a `StatefulElement` (Flutter's `State`).
--
-- `set_state(fn)` is the only supported way to change it: `fn` mutates the
-- state, then the owning element is marked dirty and the subtree is rebuilt on
-- the next frame. That is exactly Flutter's `setState`.

local std = require 'elxlibs.std'

local raise = std.raise

---@class elxstate
local M = {}

---@class State : std.object
---@field widget StatefulWidget
---@field context Element?
---@overload fun(): State
local State = std.class.new('State')

function State:__init()
    self.widget = nil
    self.context = nil
end

---@return boolean
function State:is_mounted()
    return self.context ~= nil and self.context.mounted
end

--- Called once, right after the element is mounted.
---@diagnostic disable-next-line: unused
function State:init_state() end

---@param old_widget StatefulWidget
---@diagnostic disable-next-line: unused
function State:did_update_widget(old_widget) end

--- Called when the element is discarded; release listeners/timers here.
---@diagnostic disable-next-line: unused
function State:dispose() end

---@param context BuildContext
---@return Widget?
---@diagnostic disable-next-line: unused
function State:build(context)
    raise(std.NotImplementedError(
        string.format('%s must implement build', tostring(self))))
end

--- Apply a change and schedule a rebuild. `apply` may be omitted when the
--- caller already mutated the state.
---@param apply fun()?
function State:set_state(apply)
    if apply then
        apply()
    end
    if self.context then
        self.context:mark_dirty()
    end
end

M.State = State

return M
