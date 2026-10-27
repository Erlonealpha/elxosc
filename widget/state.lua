-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Mutable state attached to a `StatefulElement` (Flutter's `State`).
--
-- `set_state(fn)` is the only supported way to change it: `fn` mutates the
-- state, then the owning element is marked dirty and the subtree is rebuilt on
-- the next frame. That is exactly Flutter's `setState`.

local std = require 'elxlibs.std'
local ticker_mod = require 'scheduler.ticker'
local controller_mod = require 'animation.controller'

local raise = std.raise
local Ticker = ticker_mod.Ticker
local AnimationController = controller_mod.AnimationController

local M = {}

---@class State : std.object
---@field widget StatefulWidget
---@field context Element?
---@field _resources table[]
---@overload fun(): self
local State = std.class.new('State', {})

function State:__init()
    self.widget = nil
    self.context = nil
    self._resources = {}
end

---@return boolean
function State:is_mounted()
    return self.context ~= nil and self.context:is_active()
end

--- Called once, right after the element is mounted.
function State:init_state() end

--- Called after the State is mounted and whenever an inherited dependency
--- changes. Listening Provider lookups are valid from this callback.
function State:did_change_dependencies() end

---@param old_widget StatefulWidget
function State:did_update_widget(old_widget) end

--- Called when the element is discarded; release listeners/timers here.
function State:dispose() end

---@param resource table
---@return table
function State:_own_resource(resource)
    self._resources[#self._resources + 1] = resource
    return resource
end

--- Create a ticker owned by this State. The WidgetsBinding must be connected to
--- a Scheduler for runtime animation; otherwise this is an explicit error.
---@param on_tick fun(dt: number, time: number)
---@return Ticker
function State:create_ticker(on_tick)
    local context = self.context
    local owner = context and context.owner
    local scheduler = owner and owner.scheduler
    if not scheduler then
        raise(std.RuntimeError('State needs a Scheduler to create a ticker'))
    end
    return self:_own_resource(Ticker(scheduler, on_tick)) --[[@as Ticker]]
end

--- Create an animation controller that is disposed with this State.
---@param options _AnimationControllerOptions
---@return AnimationController
function State:create_animation_controller(options)
    local context = self.context
    local owner = context and context.owner
    local scheduler = owner and owner.scheduler
    if not scheduler then
        raise(std.RuntimeError('State needs a Scheduler to create an animation controller'))
    end
    return self:_own_resource(AnimationController(scheduler, options)) --[[@as AnimationController]]
end

--- Internal lifecycle hook called after the user-visible dispose method.
function State:_dispose_resources()
    local failure
    for i = #self._resources, 1, -1 do
        local resource = self._resources[i]
        local release = resource.dispose or resource.stop
        if release then
            local ok, err = pcall(release, resource)
            if not ok then
                failure = failure or err
            end
        end
        self._resources[i] = nil
    end
    if failure then
        error(failure, 0)
    end
end

---@param context BuildContext
---@return Widget?
function State:build(context)
    raise(std.NotImplementedError(
        string.format('%s must implement build', tostring(self))))
end

--- Apply a change and schedule a rebuild. `apply` may be omitted when the
--- caller already mutated the state.
---@param apply fun()?
---@return boolean scheduled
function State:set_state(apply)
    local context = self.context
    if context and context.owner then
        context.owner:assert_can_build()
    end
    -- Do not silently mutate a disposed State. Flutter reports this as a
    -- lifecycle error; returning false keeps the Lua API usable by callers
    -- while making the invalid transition observable and side-effect free.
    if not self:is_mounted() then
        return false
    end
    if apply then
        apply()
    end
    if context then
        context:mark_dirty()
    end
    return true
end

M.State = State

return M
