-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- mpv property bridge for the host-independent PlayerStore.

local mp = require 'mp'

local std = require 'elxlibs.std'
local player_context = require 'widget.player_context'

local raise = std.raise
local PlayerSnapshot = player_context.PlayerSnapshot
local PlayerStore = player_context.PlayerStore

local M = {}

---@class MpPropertySubscription : std.object
---@field _active boolean
---@field _callback fun(name: string, value: any)?
---@field _owner MpPlayerContext?
---@field name string
---@overload fun(owner: MpPlayerContext, name: string, callback: fun(name: string, value: any)): self
local MpPropertySubscription = std.class.new('MpPropertySubscription', {})

function MpPropertySubscription:__init(owner, name, callback)
    self._owner = owner
    self.name = name
    self._active = true
    self._callback = callback
end

---@return boolean disposed
function MpPropertySubscription:dispose()
    if not self._active then
        return false
    end
    self._active = false
    local callback = self._callback
    local owner = self._owner
    self._callback = nil
    self._owner = nil
    if owner then
        owner:_remove_property(self.name, self)
    end
    if callback then
        mp.unobserve_property(callback)
    end
    return true
end

---@return boolean
function MpPropertySubscription:is_active()
    return self._active
end

---@class MpPlayerContextOptions
---@field on_error fun(name: string, error: any)?

---@class MpPlayerContext : std.object
---@field store PlayerStore
---@field on_error fun(name: string, error: any)?
---@field _properties table<string, MpPropertySubscription>
---@field _disposed boolean
---@overload fun(store: PlayerStore, options: MpPlayerContextOptions?): self
local MpPlayerContext = std.class.new('MpPlayerContext', {})

---@param name string
---@param subscription MpPropertySubscription
function MpPlayerContext:_remove_property(name, subscription)
    if self._properties[name] == subscription then
        self._properties[name] = nil
    end
end

function MpPlayerContext:__init(store, options)
    if not std.isinstance(store, PlayerStore) then
        raise(std.TypeError('MpPlayerContext expects a PlayerStore'))
    end
    options = options or {}
    if type(options) ~= 'table' then
        raise(std.TypeError('MpPlayerContext options must be a table'))
    end
    self.store = store
    self.on_error = options.on_error
    self._properties = {}
    self._disposed = false
end

---@param snapshot PlayerSnapshot|PlayerSnapshotFields
---@return PlayerSnapshot
function MpPlayerContext:publish(snapshot)
    if self._disposed then
        raise(std.RuntimeError('MpPlayerContext is disposed'))
    end
    return self.store:replace(snapshot)
end

---@param name string
---@param transform? fun(value: any, current: PlayerSnapshot): PlayerSnapshot|PlayerSnapshotFields?
---@return MpPropertySubscription
function MpPlayerContext:observe(name, transform)
    if self._disposed then
        raise(std.RuntimeError('MpPlayerContext is disposed'))
    end
    if type(name) ~= 'string' or name == '' then
        raise(std.ValueError('MpPlayerContext property name must be a non-empty string'))
    end
    if self._properties[name] then
        raise(std.RuntimeError(string.format(
            "MpPlayerContext property '%s' is already observed", name)))
    end
    if transform ~= nil and type(transform) ~= 'function' then
        raise(std.TypeError('MpPlayerContext transform must be a function'))
    end

    local callback
    local subscription
    callback = function(property_name, value)
        if self._disposed or (subscription and not subscription:is_active()) then
            return
        end
        local make_snapshot = transform or function(next_value, current)
            return current:copy({ [property_name] = next_value })
        end
        local ok, transformed = pcall(make_snapshot, value, self.store:get())
        ---@type PlayerSnapshot|PlayerSnapshotFields?
        local next_snapshot = transformed
        if not ok then
            if self.on_error then
                self.on_error(property_name, next_snapshot)
            end
            return
        end
        if next_snapshot == nil then
            return
        end
        local replaced, replace_error = pcall(function()
            self.store:replace(next_snapshot)
        end)
        if not replaced and self.on_error then
            self.on_error(property_name, replace_error)
        end
    end

    mp.observe_property(name, 'native', callback)
    subscription = MpPropertySubscription(self, name, callback)
    self._properties[name] = subscription
    return subscription
end

---@param name string
---@return MpPropertySubscription?
function MpPlayerContext:subscription(name)
    return self._properties[name]
end

---@return boolean disposed
function MpPlayerContext:dispose()
    if self._disposed then
        return false
    end
    self._disposed = true
    local subscriptions = {}
    for name, subscription in pairs(self._properties) do
        subscriptions[#subscriptions + 1] = subscription
        self._properties[name] = nil
    end
    for _, subscription in ipairs(subscriptions) do
        subscription:dispose()
    end
    return true
end

M.MpPropertySubscription = MpPropertySubscription
M.MpPlayerContext = MpPlayerContext

return M
