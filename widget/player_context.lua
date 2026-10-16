-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Host-independent player state values, store notifications, and the widget
-- scope that exposes the current snapshot to descendants.

local std = require 'elxlibs.std'
local provider_mod = require 'widget.provider'
local state_mod = require 'widget.state'
local widget_mod = require 'widget.widget'

local raise = std.raise
local Provider = provider_mod.Provider
local State = state_mod.State
local StatefulWidget = widget_mod.StatefulWidget

local M = {}

local readonly_table_views = setmetatable({}, { __mode = 'k' })
local readonly_table_values = setmetatable({}, { __mode = 'k' })
local snapshot_views = setmetatable({}, { __mode = 'k' })
local snapshot_view_values = setmetatable({}, { __mode = 'k' })

---@alias PlayerSnapshotValue string|number|boolean|table
---@alias PlayerSnapshotFields table<string, PlayerSnapshotValue>

---@class _PlayerSnapshotOptions
---@field [string] PlayerSnapshotValue

local function is_finite(value)
    return value == value and value ~= math.huge and value ~= -math.huge
end

---@param key any
---@return string|number|boolean
local function copy_key(key)
    local key_type = type(key)
    if key_type ~= 'string' and key_type ~= 'number' and key_type ~= 'boolean' then
        raise(std.TypeError('PlayerSnapshot table keys must be strings, numbers or booleans'))
    end
    if key_type == 'number' and not is_finite(key) then
        raise(std.ValueError('PlayerSnapshot table keys must be finite numbers'))
    end
    return key
end

---@param value any
---@param copies table<table, table>
---@param active table<table, boolean>
---@return any
local function copy_value(value, copies, active)
    local value_type = type(value)
    if value == nil or value_type == 'string' or value_type == 'boolean' then
        return value
    end
    if value_type == 'number' then
        if not is_finite(value) then
            raise(std.ValueError('PlayerSnapshot values must be finite numbers'))
        end
        return value
    end
    if value_type ~= 'table' then
        raise(std.TypeError('PlayerSnapshot values must be data values'))
    end
    if active[value] then
        raise(std.ValueError('PlayerSnapshot values must not contain cycles'))
    end
    if copies[value] then
        return copies[value]
    end

    local copy = {}
    copies[value] = copy
    active[value] = true
    for key, item in pairs(value) do
        copy[copy_key(key)] = copy_value(item, copies, active)
    end
    active[value] = nil
    return copy
end

---@param fields _PlayerSnapshotOptions?
---@return PlayerSnapshotFields
local function copy_fields(fields)
    if fields == nil then
        fields = {}
    end
    if type(fields) ~= 'table' then
        raise(std.TypeError('PlayerSnapshot expects a fields table'))
    end
    for key in pairs(fields) do
        if type(key) ~= 'string' or key == '' then
            raise(std.TypeError('PlayerSnapshot fields must have non-empty string names'))
        end
        if key:sub(1, 1) == '_' then
            raise(std.ValueError('PlayerSnapshot field names beginning with _ are reserved'))
        end
    end
    return copy_value(fields, {}, {}) --[[@as PlayerSnapshotFields]]
end

---@class PlayerSnapshot : std.object
---@field private _fields table<string, true>
---@overload fun(fields: _PlayerSnapshotOptions?): self
local PlayerSnapshot = std.class.new('PlayerSnapshot', {})

local function readonly_value(value)
    if type(value) ~= 'table' then
        return value
    end
    local view = readonly_table_views[value]
    if view then
        return view
    end
    view = {}
    readonly_table_views[value] = view
    readonly_table_values[view] = value
    setmetatable(view, {
        __index = function(_, key)
            return readonly_value(value[key])
        end,
        __newindex = function()
            raise(std.RuntimeError('PlayerSnapshot nested values are read-only'))
        end,
    })
    return view
end

---@return PlayerSnapshot
local function snapshot_from_view(value)
    return snapshot_view_values[value]
end

local snapshot_view_mt = {
    __index = function(view, key)
        local snapshot = snapshot_from_view(view)
        if key == 'get' then
            return function(_, name)
                return snapshot:get(name)
            end
        elseif key == 'to_table' then
            return function()
                return snapshot:to_table()
            end
        elseif key == 'copy' then
            return function(_, overrides)
                return snapshot:copy(overrides):readonly()
            end
        elseif key == 'readonly' then
            return function()
                return view
            end
        end
        return readonly_value(snapshot[key])
    end,
    __newindex = function()
        raise(std.RuntimeError('PlayerSnapshot is read-only'))
    end,
}

function PlayerSnapshot:readonly()
    local view = snapshot_views[self]
    if view then
        return view
    end
    view = {}
    snapshot_views[self] = view
    snapshot_view_values[view] = self
    setmetatable(view, snapshot_view_mt)
    return view
end

function PlayerSnapshot:__init(fields)
    local values = copy_fields(fields)
    self._fields = {}
    for key, value in pairs(values) do
        self._fields[key] = true
        self[key] = value
    end
end

---@param name string
---@return PlayerSnapshotValue?
function PlayerSnapshot:get(name)
    if type(name) ~= 'string' or name == '' then
        raise(std.TypeError('PlayerSnapshot.get expects a non-empty field name'))
    end
    return readonly_value(self[name])
end

---@return PlayerSnapshotFields
function PlayerSnapshot:to_table()
    local fields = {}
    for name in pairs(self._fields) do
        fields[name] = copy_value(self[name], {}, {})
    end
    return fields
end

---@param overrides _PlayerSnapshotOptions?
---@return PlayerSnapshot
function PlayerSnapshot:copy(overrides)
    local fields = self:to_table()
    if overrides ~= nil then
        local extra = copy_fields(overrides)
        for key, value in pairs(extra) do
            fields[key] = value
        end
    end
    return PlayerSnapshot(fields --[[@as _PlayerSnapshotOptions]])
end

---@class PlayerSubscription : std.object
---@field private _active boolean
---@field private _listener fun(snapshot: PlayerSnapshot, previous: PlayerSnapshot)?
---@field private _store PlayerStore?
---@overload fun(options: _PlayerSubscriptionOptions): self
local PlayerSubscription = std.class.new('PlayerSubscription', {})

---@class _PlayerSubscriptionOptions
---@field store PlayerStore
---@field listener fun(snapshot: PlayerSnapshot, previous: PlayerSnapshot)

function PlayerSubscription:__init(options)
    self._active = true
    self._listener = options.listener
    self._store = options.store
end

---@return boolean disposed
function PlayerSubscription:dispose()
    if not self._active then
        return false
    end
    self._active = false
    local store = self._store
    self._listener = nil
    self._store = nil
    if store then
        store:_remove_subscription(self)
    end
    return true
end

---@return boolean
function PlayerSubscription:is_active()
    return self._active
end

---@param snapshot PlayerSnapshot
---@param previous PlayerSnapshot
function PlayerSubscription:notify(snapshot, previous)
    if not self._active then
        return
    end
    local listener = self._listener
    if listener then
        listener(snapshot, previous)
    end
end

---@alias PlayerStoreListener fun(snapshot: PlayerSnapshot, previous: PlayerSnapshot)

local function normalize_snapshot(value)
    if std.isinstance(value, PlayerSnapshot) then
        return value
    end
    local raw = type(value) == 'table' and snapshot_from_view(value) or nil
    if raw then
        return raw
    end
    if type(value) == 'table' then
        return PlayerSnapshot(value)
    end
    raise(std.TypeError('PlayerStore expects a PlayerSnapshot or fields table'))
end

---@class PlayerStore : std.object
---@field private _snapshot PlayerSnapshot
---@field private _subscriptions PlayerSubscription[]
---@field private _notifying boolean
---@field on_error fun(error: any, subscription: PlayerSubscription?)?
---@overload fun(snapshot: PlayerSnapshot|_PlayerSnapshotOptions?, options: _PlayerStoreOptions?): self
local PlayerStore = std.class.new('PlayerStore', {})

---@class _PlayerStoreOptions
---@field on_error fun(error: any, subscription: PlayerSubscription?)

function PlayerStore:__init(snapshot, options)
    if snapshot == nil then
        snapshot = {}
    end
    self._snapshot = normalize_snapshot(snapshot)
    self._subscriptions = {}
    self._notifying = false
    options = options or {}
    if type(options) ~= 'table' then
        raise(std.TypeError('PlayerStore options must be a table'))
    end
    if options.on_error ~= nil and type(options.on_error) ~= 'function' then
        raise(std.TypeError('PlayerStore.on_error must be a function'))
    end
    self.on_error = options.on_error
end

---@return PlayerSnapshot
function PlayerStore:get()
    return self._snapshot:readonly() --[[@as PlayerSnapshot]]
end

---@param subscription PlayerSubscription
function PlayerStore:_remove_subscription(subscription)
    if self._notifying then
        return
    end
    for index, current in ipairs(self._subscriptions) do
        if current == subscription then
            table.remove(self._subscriptions, index)
            return
        end
    end
end

function PlayerStore:_compact_subscriptions()
    local active = {}
    for _, subscription in ipairs(self._subscriptions) do
        if subscription and subscription:is_active() then
            active[#active + 1] = subscription
        end
    end
    self._subscriptions = active
end

---@param snapshot PlayerSnapshot|PlayerSnapshotFields
---@return PlayerSnapshot
function PlayerStore:replace(snapshot)
    local next_snapshot = normalize_snapshot(snapshot)
    local previous = self._snapshot
    if next_snapshot == previous then
        return next_snapshot:readonly() --[[@as PlayerSnapshot]]
    end
    self._snapshot = next_snapshot

    local next_view = next_snapshot:readonly()
    local previous_view = previous:readonly()
    local count = #self._subscriptions
    local first_error = nil
    ---@type PlayerSubscription?
    local first_subscription = nil
    self._notifying = true
    for index = 1, count do
        local subscription = self._subscriptions[index]
        if subscription and subscription:is_active() then
            local ok, notify_error = pcall(
                subscription.notify, subscription, next_view, previous_view)
            if not ok and first_error == nil then
                first_error = notify_error
                first_subscription = subscription
            end
        end
    end
    self._notifying = false
    self:_compact_subscriptions()
    if first_error ~= nil then
        if self.on_error then
            self.on_error(first_error, first_subscription)
        else
            raise(first_error)
        end
    end
    return next_view --[[@as PlayerSnapshot]]
end

---@param listener PlayerStoreListener
---@return PlayerSubscription
function PlayerStore:subscribe(listener)
    if type(listener) ~= 'function' then
        raise(std.TypeError('PlayerStore.subscribe expects a function'))
    end
    local subscription = PlayerSubscription({
        store = self,
        listener = listener,
    })
    self._subscriptions[#self._subscriptions + 1] = subscription
    return subscription
end

---@class _PlayerProviderOptions
---@field snapshot PlayerSnapshot
---@field child Widget?
---@field key any?

---@class PlayerProvider : Provider
---@field snapshot PlayerSnapshot
---@field child Widget?
---@field key any?
---@overload fun(options: _PlayerProviderOptions): self
local PlayerProvider = std.class.new('PlayerProvider', { Provider })

function PlayerProvider:__init(options)
    if type(options) ~= 'table' then
        raise(std.TypeError('PlayerProvider expects an options table'))
    end
    self.key = options.key
    self.snapshot = normalize_snapshot(options.snapshot):readonly()
    self.child = options.child
end

---@param old_widget InheritedWidget
---@return boolean
function PlayerProvider:update_should_notify(old_widget)
    return self.snapshot ~= old_widget.snapshot
end

---@param context BuildContext
---@return PlayerProvider
function PlayerProvider.of(context)
    return Provider.of(context, PlayerProvider --[[@as std.Class]]) --[[@as PlayerProvider]]
end

---@param context BuildContext
---@return PlayerProvider?
function PlayerProvider.maybe_of(context)
    return Provider.maybe_of(context, PlayerProvider --[[@as std.Class]]) --[[@as PlayerProvider?]]
end

---@param context BuildContext
---@return PlayerProvider
function PlayerProvider.read(context)
    return Provider.read(context, PlayerProvider --[[@as std.Class]]) --[[@as PlayerProvider]]
end

---@param context BuildContext
---@return PlayerProvider?
function PlayerProvider.maybe_read(context)
    return Provider.maybe_read(context, PlayerProvider --[[@as std.Class]]) --[[@as PlayerProvider?]]
end

---@param context BuildContext
---@return PlayerSnapshot
function PlayerProvider.snapshot_of(context)
    return PlayerProvider.of(context).snapshot
end

---@class _PlayerScopeOptions
---@field store PlayerStore
---@field child Widget?
---@field key any?

---@class PlayerScopeState : State
---@field snapshot PlayerSnapshot
---@field subscription PlayerSubscription?
---@overload fun(): self
local PlayerScopeState = std.class.new('PlayerScopeState', { State })

function PlayerScopeState:__init()
    std.super(PlayerScopeState, self, State).__init(self)
    self.snapshot = nil
    self.subscription = nil
end

---@param store PlayerStore
function PlayerScopeState:_attach_store(store)
    if self.subscription then
        self.subscription:dispose()
    end
    self.snapshot = store:get()
    self.subscription = store:subscribe(function(snapshot)
        if self:is_mounted() then
            self:set_state(function()
                self.snapshot = snapshot
            end)
        end
    end)
end

function PlayerScopeState:init_state()
    local scope = self.widget --[[@as PlayerScope]]
    self:_attach_store(scope.store)
end

---@param old_widget StatefulWidget
function PlayerScopeState:did_update_widget(old_widget)
    local old_scope = old_widget --[[@as PlayerScope]]
    local scope = self.widget --[[@as PlayerScope]]
    if old_scope.store ~= scope.store then
        self:_attach_store(scope.store)
    end
end

function PlayerScopeState:dispose()
    if self.subscription then
        self.subscription:dispose()
        self.subscription = nil
    end
end

---@param context BuildContext
---@return Widget
function PlayerScopeState:build(context)
    local scope = self.widget --[[@as PlayerScope]]
    return PlayerProvider({
        snapshot = self.snapshot,
        child = scope.child,
    })
end

---@class PlayerScope : StatefulWidget
---@field store PlayerStore
---@field child Widget?
---@field key any?
---@overload fun(options: _PlayerScopeOptions): self
local PlayerScope = std.class.new('PlayerScope', { StatefulWidget })

function PlayerScope:__init(options)
    if type(options) ~= 'table' then
        raise(std.TypeError('PlayerScope expects an options table'))
    end
    if not std.isinstance(options.store, PlayerStore) then
        raise(std.TypeError('PlayerScope.store must be a PlayerStore'))
    end
    self.key = options.key
    self.store = options.store
    self.child = options.child
end

---@return PlayerScopeState
function PlayerScope:create_state()
    return PlayerScopeState()
end

function PlayerScope:child_widgets()
    return self.child and { self.child } or {}
end

function PlayerScope:bind_target()
    return 'child'
end

M.PlayerSnapshot = PlayerSnapshot
M.PlayerSubscription = PlayerSubscription
M.PlayerStore = PlayerStore
M.PlayerProvider = PlayerProvider
M.PlayerScopeState = PlayerScopeState
M.PlayerScope = PlayerScope

return M
