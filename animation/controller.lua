-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Frame-clock driven animation controller. It deliberately emits no PTS based
-- ASS tags: every sample invalidates the framework and produces static output.

local std = require 'elxlibs.std'
local ticker_mod = require 'scheduler.ticker'
local curve_mod = require 'animation.curve'

local Ticker = ticker_mod.Ticker
local linear = curve_mod.linear
local raise = std.raise
local min = math.min
local max = math.max

local M = {}

---@alias AnimationStatus
--- | 'dismissed'
--- | 'forward'
--- | 'reverse'
--- | 'completed'
--- | 'stopped'

---@class _AnimationControllerOptions
---@field duration number positive seconds
---@field lower_bound number? defaults to 0
---@field upper_bound number? defaults to 1
---@field value number? defaults to lower_bound
---@field curve? fun(t: number): number defaults to linear

---@class _AnimationRepeatOptions
---@field reverse boolean? alternate direction at each bound
---@field count integer? completed cycles before stopping; nil repeats forever

---@class AnimationController : std.object
---@field scheduler Scheduler
---@field duration number
---@field lower_bound number
---@field upper_bound number
---@field value number
---@field status AnimationStatus
---@overload fun(scheduler: Scheduler, options: _AnimationControllerOptions): self
local AnimationController = std.class.new('AnimationController', {})

---@param scheduler Scheduler
---@param options _AnimationControllerOptions
function AnimationController:__init(scheduler, options)
    options = options or {}
    if type(options.duration) ~= 'number' or options.duration <= 0
        or options.duration == math.huge or options.duration ~= options.duration then
        raise(std.ValueError('AnimationController.duration must be positive and finite'))
    end
    local lower = options.lower_bound == nil and 0 or options.lower_bound
    local upper = options.upper_bound == nil and 1 or options.upper_bound
    if type(lower) ~= 'number' or type(upper) ~= 'number' or lower >= upper then
        raise(std.ValueError('AnimationController bounds must be increasing numbers'))
    end
    local value = options.value == nil and lower or options.value
    if type(value) ~= 'number' then
        raise(std.TypeError('AnimationController.value must be a number'))
    end

    self.scheduler = scheduler
    self.duration = options.duration
    self.lower_bound = lower
    self.upper_bound = upper
    self.value = min(upper, max(lower, value))
    self.status = self.value == lower and 'dismissed' or 'stopped'
    self.curve = options.curve or linear
    self._listeners = {}
    self._ticker = Ticker(scheduler, function(dt, time)
        self:_tick(dt, time)
    end)
    self._from = self.value
    self._target = self.value
    self._elapsed = 0
    self._repeat = false
    self._repeat_reverse = false
    self._repeat_count = nil
    self._repeat_cycles = 0
    self._disposed = false
end

---@param listener fun(controller: AnimationController)
function AnimationController:add_listener(listener)
    if self._disposed then
        return
    end
    self._listeners[listener] = true
end

---@param listener fun(controller: AnimationController)
function AnimationController:remove_listener(listener)
    self._listeners[listener] = nil
end

function AnimationController:_notify()
    local listeners = {}
    for listener in pairs(self._listeners) do
        listeners[#listeners + 1] = listener
    end
    for _, listener in ipairs(listeners) do
        listener(self)
    end
end

---@return boolean
function AnimationController:is_animating()
    return self._ticker:is_active()
end

---@param value number
---@return number
function AnimationController:_clamp(value)
    return min(self.upper_bound, max(self.lower_bound, value))
end

---@param target number
---@param status AnimationStatus
---@param from number?
function AnimationController:_start(target, status, from)
    if self._disposed then
        raise(std.RuntimeError('AnimationController is disposed'))
    end
    ---@type number
    local start = from == nil and self.value or from
    self._from = self:_clamp(start)
    self._target = self:_clamp(target)
    self._elapsed = 0
    self.status = status
    self:_notify()
    if self._from == self._target then
        self.value = self._target
        self:_finish()
    else
        self._ticker:start()
    end
end

---@param from number?
function AnimationController:forward(from)
    self._repeat = false
    self._repeat_count = nil
    self:_start(self.upper_bound, 'forward', from)
end

---@param from number?
function AnimationController:reverse(from)
    self._repeat = false
    self._repeat_count = nil
    self:_start(self.lower_bound, 'reverse', from)
end

---@param options _AnimationRepeatOptions?
function AnimationController:repeat_animation(options)
    options = options or {}
    local count = options.count
    if count ~= nil and (type(count) ~= 'number' or count < 1 or count % 1 ~= 0) then
        raise(std.ValueError('AnimationController repeat count must be a positive integer'))
    end
    self._repeat = true
    self._repeat_reverse = options.reverse == true
    self._repeat_count = count
    self._repeat_cycles = 0
    self.value = self.lower_bound
    self:_start(self.upper_bound, 'forward', self.lower_bound)
end

function AnimationController:_finish()
    self._ticker:stop()
    self._repeat = false
    if self.value == self.lower_bound then
        self.status = 'dismissed'
    else
        self.status = 'completed'
    end
    self:_notify()
end

function AnimationController:_next_repeat()
    if not self._repeat_reverse then
        self._repeat_cycles = self._repeat_cycles + 1
        if self._repeat_count and self._repeat_cycles >= self._repeat_count then
            self:_finish()
            return
        end
        self.value = self.lower_bound
        self:_start(self.upper_bound, 'forward', self.lower_bound)
        return
    end

    if self.status == 'forward' then
        self:_start(self.lower_bound, 'reverse', self.upper_bound)
        return
    end
    self._repeat_cycles = self._repeat_cycles + 1
    if self._repeat_count and self._repeat_cycles >= self._repeat_count then
        self:_finish()
        return
    end
    self:_start(self.upper_bound, 'forward', self.lower_bound)
end

---@param dt number
---@param time number
function AnimationController:_tick(dt, time)
    if not self._ticker:is_active() or self._disposed then
        return
    end
    dt = max(0, dt)
    self._elapsed = min(self.duration, self._elapsed + dt)
    local progress = self._elapsed / self.duration
    local curved = self.curve(progress)
    if type(curved) ~= 'number' then
        raise(std.TypeError('AnimationController curve must return a number'))
    end
    self.value = self._from + (self._target - self._from) * curved
    self:_notify()
    if progress >= 1 then
        self.value = self._target
        if self._repeat then
            self:_next_repeat()
        else
            self:_finish()
        end
    end
end

function AnimationController:stop()
    if self._disposed then
        return
    end
    if self._ticker:is_active() then
        self._ticker:stop()
        self._repeat = false
        self._repeat_count = nil
        self.status = 'stopped'
        self:_notify()
    end
end

function AnimationController:reset()
    self:stop()
    self.value = self.lower_bound
    self.status = 'dismissed'
    self:_notify()
end

function AnimationController:dispose()
    if self._disposed then
        return
    end
    self:stop()
    self._disposed = true
    self._listeners = {}
end

M.AnimationController = AnimationController

return M
