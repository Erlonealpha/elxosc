-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Host-independent player state values, store notifications, and the widget
-- scope that exposes the current snapshot to descendants.

local std = require 'elxlibs.std'
local builder_mod = require 'src.widget.builder'
local provider_mod = require 'src.widget.provider'
local state_mod = require 'src.widget.state'
local widget_mod = require 'src.widget.widget'

local raise = std.raise
local Provider = provider_mod.Provider
local State = state_mod.State
local StatelessWidget = widget_mod.StatelessWidget
local StatefulWidget = widget_mod.StatefulWidget

---@class elxosc.mod.player.src.context
local M = {}

-- LuaJIT weak-key tables are not ephemerons: a strong value that reaches its
-- key keeps both alive. Forward caches must also weaken values; reverse maps
-- keep the backing data alive only while a caller holds the view.
local readonly_table_views = setmetatable({}, { __mode = 'kv' })
local readonly_table_values = setmetatable({}, { __mode = 'k' })
local snapshot_views = setmetatable({}, { __mode = 'kv' })
local snapshot_view_values = setmetatable({}, { __mode = 'k' })

local function unwrap_readonly(value)
    return readonly_table_values[value] or value
end

---@param left any
---@param right any
---@param seen table<table, table>?
---@return boolean
local function data_equal(left, right, seen)
    if left == right then
        return true
    end
    if type(left) ~= 'table' or type(right) ~= 'table' then
        return false
    end
    left = unwrap_readonly(left)
    right = unwrap_readonly(right)
    if left == right then
        return true
    end
    seen = seen or {}
    if seen[left] and seen[left][right] then
        return true
    end
    seen[left] = seen[left] or {}
    seen[left][right] = true
    for key, value in pairs(left) do
        if not data_equal(value, right[key], seen) then
            return false
        end
    end
    for key in pairs(right) do
        if left[key] == nil then
            return false
        end
    end
    return true
end

---@alias elxosc.player.PlayerSnapshotValue string|number|boolean|table
---@alias elxosc.player.PlayerSnapshotFields table<string, elxosc.player.PlayerSnapshotValue>
---@alias elxosc.player.CapabilityStatus
--- | 'available'
--- | 'unavailable'
--- | 'loading'
--- | 'error'

---@class elxosc.player.CapabilityInfo
---@field status elxosc.player.CapabilityStatus
---@field detail string?
---@field error string?

---@class elxosc.player._PlayerSnapshotOptions
---@field [string] elxosc.player.PlayerSnapshotValue

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

---@param fields elxosc.player._PlayerSnapshotOptions?
---@return elxosc.player.PlayerSnapshotFields
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
    local capabilities = fields.capabilities
    if capabilities ~= nil then
        if type(capabilities) ~= 'table' then
            raise(std.TypeError('PlayerSnapshot.capabilities must be a table'))
        end
        local statuses = {
            available = true,
            unavailable = true,
            loading = true,
            error = true,
        }
        for name, info in pairs(capabilities) do
            if type(name) ~= 'string' or name == '' then
                raise(std.TypeError('PlayerSnapshot capability names must be non-empty strings'))
            end
            if type(info) ~= 'table' or not statuses[info.status] then
                raise(std.ValueError(
                    'PlayerSnapshot capability status must be available, unavailable, loading or error'))
            end
            if info.detail ~= nil and type(info.detail) ~= 'string' then
                raise(std.TypeError('PlayerSnapshot capability detail must be a string'))
            end
            if info.error ~= nil and type(info.error) ~= 'string' then
                raise(std.TypeError('PlayerSnapshot capability error must be a string'))
            end
        end
    end
    return copy_value(fields, {}, {}) --[[@as elxosc.player.PlayerSnapshotFields]]
end

---@class elxosc.player.PlayerSnapshot : std.object
---@field private _fields table<string, true>
---@overload fun(fields: elxosc.player._PlayerSnapshotOptions?): self
local PlayerSnapshot = std.class.new('PlayerSnapshot' --[[@as 'elxosc.player.PlayerSnapshot']])

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

---@return elxosc.player.PlayerSnapshot
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
---@return elxosc.player.PlayerSnapshotValue?
function PlayerSnapshot:get(name)
    if type(name) ~= 'string' or name == '' then
        raise(std.TypeError('PlayerSnapshot.get expects a non-empty field name'))
    end
    return readonly_value(self[name])
end

---@param name string
---@return elxosc.player.CapabilityInfo
function PlayerSnapshot:capability(name)
    if type(name) ~= 'string' or name == '' then
        raise(std.TypeError('PlayerSnapshot.capability expects a non-empty name'))
    end
    local capabilities = self.capabilities
    if type(capabilities) ~= 'table' or capabilities[name] == nil then
        return readonly_value({
            status = 'unavailable',
            detail = 'not provided',
        }) --[[@as elxosc.player.CapabilityInfo]]
    end
    return readonly_value(capabilities[name]) --[[@as elxosc.player.CapabilityInfo]]
end

---@return elxosc.player.PlayerSnapshotFields
function PlayerSnapshot:to_table()
    local fields = {}
    for name in pairs(self._fields) do
        fields[name] = copy_value(self[name], {}, {})
    end
    return fields
end

---@param overrides elxosc.player._PlayerSnapshotOptions?
---@return elxosc.player.PlayerSnapshot
function PlayerSnapshot:copy(overrides)
    local fields = self:to_table()
    if overrides ~= nil then
        local extra = copy_fields(overrides)
        for key, value in pairs(extra) do
            fields[key] = value
        end
    end
    return PlayerSnapshot(fields --[[@as elxosc.player._PlayerSnapshotOptions]])
end

---@class elxosc.player.PlayerSubscription : std.object
---@field private _active boolean
---@field private _listener fun(snapshot: elxosc.player.PlayerSnapshot, previous: elxosc.player.PlayerSnapshot)?
---@field private _selector fun(snapshot: elxosc.player.PlayerSnapshot): any?
---@field private _selector_listener fun(selected: any?, previous_selected: any?, snapshot: elxosc.player.PlayerSnapshot, previous: elxosc.player.PlayerSnapshot)?
---@field private _equals fun(left: any?, right: any?): boolean
---@field private _selected any?
---@field private _store elxosc.player.PlayerStore?
---@overload fun(options: elxosc.player._PlayerSubscriptionOptions): self
local PlayerSubscription = std.class.new('PlayerSubscription' --[[@as 'elxosc.player.PlayerSubscription']])

---@class elxosc.player._PlayerSubscriptionOptions
---@field store elxosc.player.PlayerStore
---@field listener? fun(snapshot: elxosc.player.PlayerSnapshot, previous: elxosc.player.PlayerSnapshot)
---@field selector? fun(snapshot: elxosc.player.PlayerSnapshot): any?
---@field selector_listener? fun(selected: any?, previous_selected: any?, snapshot: elxosc.player.PlayerSnapshot, previous: elxosc.player.PlayerSnapshot)
---@field equals? fun(left: any?, right: any?): boolean
---@field selected? any

function PlayerSubscription:__init(options)
    self._active = true
    self._listener = options.listener
    self._selector = options.selector
    self._selector_listener = options.selector_listener
    self._equals = options.equals or data_equal
    self._selected = options.selected
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

---@param snapshot elxosc.player.PlayerSnapshot
---@param previous elxosc.player.PlayerSnapshot
function PlayerSubscription:notify(snapshot, previous)
    if not self._active then
        return
    end
    if self._selector then
        local selected = self._selector(snapshot)
        local previous_selected = self._selected
        self._selected = selected
        if self._equals(selected, previous_selected) then
            return
        end
        local selector_listener = self._selector_listener
        if selector_listener then
            selector_listener(selected, previous_selected, snapshot, previous)
        end
        return
    end
    local listener = self._listener
    if listener then
        listener(snapshot, previous)
    end
end

---@alias elxosc.player.PlayerStoreListener fun(snapshot: elxosc.player.PlayerSnapshot, previous: elxosc.player.PlayerSnapshot)

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

---@class elxosc.player.PlayerStore : std.object
---@field private _snapshot elxosc.player.PlayerSnapshot
---@field private _subscriptions elxosc.player.PlayerSubscription[]
---@field private _notifying boolean
---@field on_error fun(error: any, subscription: elxosc.player.PlayerSubscription?)?
---@overload fun(snapshot: elxosc.player.PlayerSnapshot|elxosc.player._PlayerSnapshotOptions?, options: elxosc.player._PlayerStoreOptions?): self
local PlayerStore = std.class.new('PlayerStore' --[[@as 'elxosc.player.PlayerStore']])

---@class elxosc.player._PlayerStoreOptions
---@field on_error fun(error: any, subscription: elxosc.player.PlayerSubscription?)

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

---@return elxosc.player.PlayerSnapshot
function PlayerStore:get()
    return self._snapshot:readonly() --[[@as elxosc.player.PlayerSnapshot]]
end

---@param subscription elxosc.player.PlayerSubscription
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

---@param snapshot elxosc.player.PlayerSnapshot|elxosc.player.PlayerSnapshotFields
---@return elxosc.player.PlayerSnapshot
function PlayerStore:replace(snapshot)
    local next_snapshot = normalize_snapshot(snapshot)
    local previous = self._snapshot
    if next_snapshot == previous then
        return next_snapshot:readonly() --[[@as elxosc.player.PlayerSnapshot]]
    end
    self._snapshot = next_snapshot

    local next_view = next_snapshot:readonly()
    local previous_view = previous:readonly()
    local count = #self._subscriptions
    local first_error = nil
    ---@type elxosc.player.PlayerSubscription?
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
    return next_view --[[@as elxosc.player.PlayerSnapshot]]
end

---@param listener elxosc.player.PlayerStoreListener
---@return elxosc.player.PlayerSubscription
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

---@param selector fun(snapshot: elxosc.player.PlayerSnapshot): any?
---@param listener fun(selected: any?, previous_selected: any?, snapshot: elxosc.player.PlayerSnapshot, previous: elxosc.player.PlayerSnapshot)
---@param equals? fun(left: any?, right: any?): boolean
---@return elxosc.player.PlayerSubscription
function PlayerStore:subscribe_selector(selector, listener, equals)
    if type(selector) ~= 'function' then
        raise(std.TypeError('PlayerStore.subscribe_selector expects a selector function'))
    end
    if type(listener) ~= 'function' then
        raise(std.TypeError('PlayerStore.subscribe_selector expects a listener function'))
    end
    if equals ~= nil and type(equals) ~= 'function' then
        raise(std.TypeError('PlayerStore.subscribe_selector equals must be a function'))
    end
    local current = self._snapshot:readonly()
    local selected = selector(current)
    local subscription = PlayerSubscription({
        store = self,
        selector = selector,
        selector_listener = listener,
        equals = equals or data_equal,
        selected = selected,
    })
    self._subscriptions[#self._subscriptions + 1] = subscription
    return subscription
end

---@class elxosc.player._PlayerProviderOptions
---@field snapshot elxosc.player.PlayerSnapshot
---@field child Widget?
---@field key any?

---@class elxosc.player.PlayerProvider : Provider
---@field snapshot elxosc.player.PlayerSnapshot
---@field child Widget?
---@field key any?
---@overload fun(options: elxosc.player._PlayerProviderOptions): self
local PlayerProvider = std.class.new('PlayerProvider' --[[@as 'elxosc.player.PlayerProvider']], Provider)

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
---@return elxosc.player.PlayerProvider
function PlayerProvider.of(context)
    return Provider.of(context, PlayerProvider --[[@as std.class]]) --[[@as elxosc.player.PlayerProvider]]
end

---@param context BuildContext
---@return elxosc.player.PlayerProvider?
function PlayerProvider.maybe_of(context)
    return Provider.maybe_of(context, PlayerProvider --[[@as std.class]]) --[[@as elxosc.player.PlayerProvider?]]
end

---@param context BuildContext
---@return elxosc.player.PlayerProvider
function PlayerProvider.read(context)
    return Provider.read(context, PlayerProvider --[[@as std.class]]) --[[@as elxosc.player.PlayerProvider]]
end

---@param context BuildContext
---@return elxosc.player.PlayerProvider?
function PlayerProvider.maybe_read(context)
    return Provider.maybe_read(context, PlayerProvider --[[@as std.class]]) --[[@as elxosc.player.PlayerProvider?]]
end

---@param context BuildContext
---@return elxosc.player.PlayerSnapshot
function PlayerProvider.snapshot_of(context)
    return PlayerProvider.of(context).snapshot
end

---@alias elxosc.player.PlayerCapabilityBuilder fun(info: elxosc.player.CapabilityInfo, snapshot: elxosc.player.PlayerSnapshot, context: BuildContext): Widget?

---@class elxosc.player._PlayerCapabilityOptions
---@field name string
---@field builder elxosc.player.PlayerCapabilityBuilder
---@field key any?

---@class elxosc.player.PlayerCapability : StatelessWidget
---@field name string
---@field builder elxosc.player.PlayerCapabilityBuilder
---@overload fun(options: elxosc.player._PlayerCapabilityOptions): self
local PlayerCapability = std.class.new('PlayerCapability' --[[@as 'elxosc.player.PlayerCapability']], StatelessWidget)

function PlayerCapability:__init(options)
    if type(options) ~= 'table' then
        raise(std.TypeError('PlayerCapability expects an options table'))
    end
    if type(options.name) ~= 'string' or options.name == '' then
        raise(std.ValueError('PlayerCapability.name must be non-empty'))
    end
    builder_mod.validate_callback(options.builder, 'PlayerCapability.builder')
    self.key = options.key
    self.name = options.name
    self.builder = options.builder
end

---@param context BuildContext
---@return Widget?
function PlayerCapability:build(context)
    local provider = PlayerProvider.of(context)
    local snapshot = provider.snapshot
    local info = snapshot:capability(self.name)
    return builder_mod.validate_result(
        self.builder(info, snapshot, context), 'PlayerCapability.builder')
end

---@class elxosc.player._PlayerScopeOptions
---@field store elxosc.player.PlayerStore
---@field child Widget?
---@field key any?

---@class elxosc.player.PlayerScopeState : State
---@field snapshot elxosc.player.PlayerSnapshot
---@field subscription elxosc.player.PlayerSubscription?
---@overload fun(): self
local PlayerScopeState = std.class.new('PlayerScopeState' --[[@as 'elxosc.player.PlayerScopeState']], State)

function PlayerScopeState:__init()
    std.super(PlayerScopeState, self, State).__init(self)
    self.snapshot = nil
    self.subscription = nil
end

---@param store elxosc.player.PlayerStore
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
    local scope = self.widget --[[@as elxosc.player.PlayerScope]]
    self:_attach_store(scope.store)
end

---@param old_widget StatefulWidget
function PlayerScopeState:did_update_widget(old_widget)
    local old_scope = old_widget --[[@as elxosc.player.PlayerScope]]
    local scope = self.widget --[[@as elxosc.player.PlayerScope]]
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
    local scope = self.widget --[[@as elxosc.player.PlayerScope]]
    return PlayerProvider({
        snapshot = self.snapshot,
        child = scope.child,
    })
end

---@class elxosc.player.PlayerScope : StatefulWidget
---@field store elxosc.player.PlayerStore
---@field child Widget?
---@field key any?
---@overload fun(options: elxosc.player._PlayerScopeOptions): self
local PlayerScope = std.class.new('PlayerScope' --[[@as 'elxosc.player.PlayerScope']], StatefulWidget)

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

---@return elxosc.player.PlayerScopeState
function PlayerScope:create_state()
    return PlayerScopeState()
end

function PlayerScope:child_widgets()
    return self.child and { self.child } or {}
end

M.PlayerSnapshot = PlayerSnapshot
M.PlayerSubscription = PlayerSubscription
M.PlayerStore = PlayerStore
M.PlayerProvider = PlayerProvider
M.PlayerCapability = PlayerCapability
M.PlayerScopeState = PlayerScopeState
M.PlayerScope = PlayerScope

return M
