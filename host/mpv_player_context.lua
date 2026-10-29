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

local DEFAULT_PLAYER_PROPERTIES = {
    { name = 'pause', field = 'pause' },
    { name = 'eof-reached', field = 'eof_reached' },
    { name = 'seeking', field = 'seeking' },
    { name = 'paused-for-cache', field = 'buffering' },
    { name = 'media-title', field = 'media_title' },
    { name = 'filename', field = 'filename' },
    { name = 'path', field = 'path' },
    { name = 'time-pos', field = 'time_pos' },
    { name = 'duration', field = 'duration' },
    { name = 'percent-pos', field = 'percent_pos' },
    { name = 'playtime-remaining', field = 'playtime_remaining' },
    { name = 'demuxer-cache-duration', field = 'buffered_duration' },
    { name = 'demuxer-cache-state', field = 'cache_state' },
    { name = 'playlist-pos', field = 'playlist_pos' },
    { name = 'playlist-count', field = 'playlist_count' },
    { name = 'chapter', field = 'chapter' },
    { name = 'chapter-list', field = 'chapter_list' },
    { name = 'track-list', field = 'track_list' },
    { name = 'fullscreen', field = 'fullscreen' },
    { name = 'border', field = 'border' },
    { name = 'title-bar', field = 'title_bar' },
    { name = 'window-maximized', field = 'window_maximized' },
    { name = 'ontop', field = 'ontop' },
    { name = 'idle-active', field = 'idle_active' },
    { name = 'mute', field = 'mute' },
    { name = 'volume', field = 'volume' },
    { name = 'volume-max', field = 'volume_max' },
    { name = 'loop-file', field = 'loop_file' },
}

local BOOLEAN_FIELDS = {
    pause = true,
    eof_reached = true,
    seeking = true,
    buffering = true,
    fullscreen = true,
    border = true,
    title_bar = true,
    window_maximized = true,
    ontop = true,
    idle_active = true,
    mute = true,
    loop_file = true,
}

local TABLE_FIELDS = {
    cache_state = true,
    chapter_list = true,
    track_list = true,
}

local function normalize_number(value)
    if value == nil then
        return nil
    end
    value = tonumber(value)
    if value == nil or value ~= value or value == math.huge or value == -math.huge then
        return nil
    end
    return value
end

local function normalize_text(value)
    if value == nil then
        return nil
    end
    value = tostring(value)
    return value ~= '' and value or nil
end

local function normalize_boolean(value)
    if value == nil then
        return nil
    end
    if type(value) == 'boolean' then
        return value
    end
    if value == 'yes' or value == 'true' or value == 1 then
        return true
    end
    if value == 'no' or value == 'false' or value == 0 then
        return false
    end
    return nil
end

local function normalize_property(field, value)
    if BOOLEAN_FIELDS[field] then
        return normalize_boolean(value)
    end
    if field == 'media_title' or field == 'filename' or field == 'path' then
        return normalize_text(value)
    end
    if TABLE_FIELDS[field] then
        return value
    end
    return normalize_number(value)
end

---@class MpPropertySubscription : std.object
---@field _active boolean
---@field _callback fun(name: string, value: any)?
---@field _owner MpPlayerContext?
---@field name string
---@field _batch_group table?
---@overload fun(owner: MpPlayerContext, name: string, callback: fun(name: string, value: any)): self
local MpPropertySubscription = std.class.new('MpPropertySubscription', {})

function MpPropertySubscription:__init(owner, name, callback)
    self._owner = owner
    self.name = name
    self._active = true
    self._callback = callback
    self._batch_group = nil
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

---@class MpCapabilitySubscription : std.object
---@field _active boolean
---@field _owner MpPlayerContext?
---@field name string
---@field _handle any
---@overload fun(owner: MpPlayerContext, name: string): self
local MpCapabilitySubscription = std.class.new('MpCapabilitySubscription', {})

function MpCapabilitySubscription:__init(owner, name)
    self._active = true
    self._owner = owner
    self.name = name
    self._handle = nil
end

---@param handle any
function MpCapabilitySubscription:set_handle(handle)
    self._handle = handle
end

---@return boolean disposed
function MpCapabilitySubscription:dispose()
    if not self._active then
        return false
    end
    self._active = false
    local owner = self._owner
    local handle = self._handle
    self._owner = nil
    self._handle = nil
    if owner then
        owner:_remove_capability(self.name, self)
    end
    if type(handle) == 'function' then
        handle()
    elseif type(handle) == 'table' and type(handle.dispose) == 'function' then
        handle:dispose()
    elseif type(handle) == 'table' and type(handle.stop) == 'function' then
        handle:stop()
    end
    return true
end

---@return boolean
function MpCapabilitySubscription:is_active()
    return self._active
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
---@field _batches table<table, true>
---@field _capabilities table<string, MpCapabilitySubscription>
---@field _disposed boolean
---@overload fun(store: PlayerStore, options: MpPlayerContextOptions?): self
local MpPlayerContext = std.class.new('MpPlayerContext', {})

---@param name string
---@param subscription MpPropertySubscription
function MpPlayerContext:_remove_property(name, subscription)
    if self._properties[name] == subscription then
        self._properties[name] = nil
    end
    local group = subscription._batch_group
    if group then
        group.subscriptions[name] = nil
        if next(group.subscriptions) == nil then
            group.disposed = true
            if group.timer and type(group.timer.kill) == 'function' then
                group.timer:kill()
            end
            self._batches[group] = nil
        end
    end
end

---@param name string
---@param subscription MpCapabilitySubscription
function MpPlayerContext:_remove_capability(name, subscription)
    if self._capabilities[name] == subscription then
        self._capabilities[name] = nil
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
    self._batches = {}
    self._capabilities = {}
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

---@class MpBatchPropertyDefinition
---@field name string mpv property name
---@field field string PlayerSnapshot field name
---@field normalize fun(value: any): any?

---@param definitions MpBatchPropertyDefinition[]
---@return MpPropertySubscription[]
function MpPlayerContext:observe_batch(definitions)
    if self._disposed then
        raise(std.RuntimeError('MpPlayerContext is disposed'))
    end
    if type(definitions) ~= 'table' or #definitions == 0 then
        raise(std.TypeError('MpPlayerContext.observe_batch expects definitions'))
    end

    local group = {
        subscriptions = {},
        definitions = {},
        pending_names = {},
        pending_values = {},
        timer = nil,
        disposed = false,
    }
    local seen = {}
    for _, definition in ipairs(definitions) do
        if type(definition) ~= 'table'
            or type(definition.name) ~= 'string' or definition.name == ''
            or type(definition.field) ~= 'string' or definition.field == '' then
            raise(std.TypeError('MpPlayerContext batch definitions need name and field'))
        end
        if seen[definition.name] or self._properties[definition.name] then
            raise(std.RuntimeError(string.format(
                "MpPlayerContext property '%s' is already observed", definition.name)))
        end
        if definition.normalize ~= nil and type(definition.normalize) ~= 'function' then
            raise(std.TypeError('MpPlayerContext batch normalize must be a function'))
        end
        seen[definition.name] = true
        group.definitions[#group.definitions + 1] = definition
    end

    local function flush()
        group.timer = nil
        if group.disposed or self._disposed then
            return
        end
        local pending_names = group.pending_names
        local pending_values = group.pending_values
        group.pending_names = {}
        group.pending_values = {}

        local fields = {}
        local error_name
        local error_value
        for _, definition in ipairs(group.definitions) do
            if pending_names[definition.name] then
                ---@type fun(value: any): any?
                local normalize = definition.normalize or function(value)
                    return value
                end
                local ok, value = pcall(normalize, pending_values[definition.name])
                if not ok then
                    error_name = definition.name
                    error_value = value
                    break
                end
                fields[definition.field] = value
            end
        end
        if error_name then
            if self.on_error then
                self.on_error(error_name, error_value)
            end
            return
        end
        if next(fields) == nil then
            return
        end
        local ok, replace_error = pcall(function()
            self.store:replace(self.store:get():copy(fields))
        end)
        if not ok and self.on_error then
            self.on_error('batch', replace_error)
        end
    end

    local function schedule()
        if group.timer or group.disposed or self._disposed then
            return
        end
        if type(mp.add_timeout) == 'function' then
            group.timer = mp.add_timeout(0, flush)
        else
            flush()
        end
    end

    self._batches[group] = true
    local subscriptions = {}
    for _, definition in ipairs(group.definitions) do
        local property_name = definition.name
        local callback
        callback = function(_, value)
            local subscription = group.subscriptions[property_name]
            if group.disposed or self._disposed
                or not subscription or not subscription:is_active() then
                return
            end
            group.pending_names[property_name] = true
            group.pending_values[property_name] = value
            schedule()
        end
        mp.observe_property(property_name, 'native', callback)
        local subscription = MpPropertySubscription(self, property_name, callback)
        subscription._batch_group = group
        group.subscriptions[property_name] = subscription
        self._properties[property_name] = subscription
        subscriptions[#subscriptions + 1] = subscription
    end
    return subscriptions
end

--- Observe the stable playback fields consumed by the default player shell.
--- The method remains host-side; widgets only receive the immutable snapshot.
---@param options? { batch: boolean? }
---@return MpPropertySubscription[]
function MpPlayerContext:observe_default_properties(options)
    options = options or {}
    if options.batch == true then
        local definitions = {}
        for _, definition in ipairs(DEFAULT_PLAYER_PROPERTIES) do
            definitions[#definitions + 1] = {
                name = definition.name,
                field = definition.field,
                normalize = function(value)
                    return normalize_property(definition.field, value)
                end,
            }
        end
        return self:observe_batch(definitions)
    end
    local subscriptions = {}
    for _, definition in ipairs(DEFAULT_PLAYER_PROPERTIES) do
        subscriptions[#subscriptions + 1] = self:observe(definition.name,
            function(value, current)
                return current:copy({
                    [definition.field] = normalize_property(definition.field, value),
                })
            end)
    end
    return subscriptions
end

---@param name string
---@param status CapabilityStatus
---@param detail string?
---@param error_message string?
function MpPlayerContext:set_capability(name, status, detail, error_message)
    if self._disposed then
        raise(std.RuntimeError('MpPlayerContext is disposed'))
    end
    if type(name) ~= 'string' or name == '' then
        raise(std.ValueError('MpPlayerContext capability name must be non-empty'))
    end
    if status ~= 'available' and status ~= 'unavailable'
        and status ~= 'loading' and status ~= 'error' then
        raise(std.ValueError('MpPlayerContext capability status is invalid'))
    end
    if detail ~= nil and type(detail) ~= 'string' then
        raise(std.TypeError('MpPlayerContext capability detail must be a string'))
    end
    if error_message ~= nil and type(error_message) ~= 'string' then
        raise(std.TypeError('MpPlayerContext capability error must be a string'))
    end
    local current = self.store:get()
    local next_capabilities = current:to_table().capabilities or {}
    next_capabilities[name] = {
        status = status,
        detail = detail,
        error = error_message,
    }
    return self.store:replace(current:copy({ capabilities = next_capabilities }))
end

---@class MpCapabilityAdapter
---@field start fun(report: fun(status: CapabilityStatus, detail: string?, error: string?)): any

---@param name string
---@param adapter MpCapabilityAdapter|fun(report: fun(status: CapabilityStatus, detail: string?, error: string?)): any
---@return MpCapabilitySubscription
function MpPlayerContext:observe_capability(name, adapter)
    if self._disposed then
        raise(std.RuntimeError('MpPlayerContext is disposed'))
    end
    if type(name) ~= 'string' or name == '' then
        raise(std.ValueError('MpPlayerContext capability name must be non-empty'))
    end
    if self._capabilities[name] then
        raise(std.RuntimeError(string.format(
            "MpPlayerContext capability '%s' is already observed", name)))
    end
    local start = type(adapter) == 'function' and adapter or type(adapter) == 'table'
        and adapter.start or nil
    if type(start) ~= 'function' then
        raise(std.TypeError('MpPlayerContext capability adapter needs a start function'))
    end

    local subscription = MpCapabilitySubscription(self, name)
    self._capabilities[name] = subscription
    self:set_capability(name, 'loading', 'starting')

    local function report(status, detail, error_message)
        if self._disposed or not subscription:is_active() then
            return
        end
        if status ~= 'available' and status ~= 'unavailable'
            and status ~= 'loading' and status ~= 'error' then
            local invalid = 'adapter reported invalid capability status: ' .. tostring(status)
            pcall(self.set_capability, self, name, 'error', 'adapter failed', invalid)
            if self.on_error then
                self.on_error(name, invalid)
            end
            return
        end
        local ok, report_error = pcall(function()
            self:set_capability(name, status, detail, error_message)
        end)
        if not ok and self.on_error then
            self.on_error(name, report_error)
        end
    end

    local ok, handle = pcall(start, report)
    if not ok then
        report('error', 'adapter failed', tostring(handle))
    elseif handle ~= nil
        and type(handle) ~= 'function'
        and not (type(handle) == 'table'
            and (type(handle.dispose) == 'function' or type(handle.stop) == 'function')) then
        report('error', 'adapter returned an invalid handle', 'invalid disposable')
    else
        subscription:set_handle(handle)
    end
    return subscription
end

---@param name string
---@return MpPropertySubscription?
function MpPlayerContext:subscription(name)
    return self._properties[name]
end

---@param name string
---@return MpCapabilitySubscription?
function MpPlayerContext:capability_subscription(name)
    return self._capabilities[name]
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
    local capabilities = {}
    for name, subscription in pairs(self._capabilities) do
        capabilities[#capabilities + 1] = subscription
        self._capabilities[name] = nil
    end
    for _, subscription in ipairs(capabilities) do
        subscription:dispose()
    end
    return true
end

M.MpPropertySubscription = MpPropertySubscription
M.MpCapabilitySubscription = MpCapabilitySubscription
M.MpPlayerContext = MpPlayerContext

return M
