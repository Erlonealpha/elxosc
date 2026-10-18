-- Host-independent visibility composition for controls and other widgets.

local std = require 'elxlibs.std'
local player_context = require 'widget.player_context'
local state_mod = require 'widget.state'
local widget_mod = require 'widget.widget'

local raise = std.raise
local PlayerProvider = player_context.PlayerProvider
local State = state_mod.State
local StatefulWidget = widget_mod.StatefulWidget

local M = {}

---@alias AutoHideMode
---| 'auto'
---| 'always'
---| 'never'

---@alias AutoHideEvent
---| 'move'
---| 'leave'

---@class AutoHideConfigOptions
---@field controls_visibility AutoHideMode?
---@field mode AutoHideMode?

---@class AutoHideConfig : std.object
---@field controls_visibility AutoHideMode
---@overload fun(options?: AutoHideConfigOptions): self
local AutoHideConfig = std.class.new('AutoHideConfig', {})

local VALID_MODES = {
    auto = true,
    always = true,
    never = true,
}

---@param value any
---@return AutoHideMode
local function validate_mode(value)
    if type(value) ~= 'string' or not VALID_MODES[value] then
        raise(std.ValueError('controls_visibility must be auto, always, or never'))
    end
    return value --[[@as AutoHideMode]]
end

---@param value any
---@return AutoHideMode
local function normalize_mode(value)
    if value == nil then
        return 'auto' --[[@as AutoHideMode]]
    end
    return validate_mode(value)
end

function AutoHideConfig:__init(options)
    options = options or {}
    if type(options) ~= 'table' then
        raise(std.TypeError('AutoHideConfig expects an options table'))
    end
    local mode = options.controls_visibility
    if mode ~= nil and options.mode ~= nil and mode ~= options.mode then
        raise(std.ValueError('AutoHideConfig mode values must agree'))
    end
    self.controls_visibility = normalize_mode(mode or options.mode)
end

---@param snapshot PlayerSnapshot?
---@return AutoHideConfig
function AutoHideConfig.from_snapshot(snapshot)
    if snapshot == nil then
        return AutoHideConfig()
    end
    local mode = snapshot:get('controls_visibility') --[[@as AutoHideMode?]]
    return AutoHideConfig({
        controls_visibility = mode,
    })
end

---@class AutoHideSubscription : std.object
---@field _active boolean
---@field _owner AutoHideController?
---@field _callback fun(event: AutoHideEvent)?
---@overload fun(owner: AutoHideController, callback: fun(event: AutoHideEvent)): self
local AutoHideSubscription = std.class.new('AutoHideSubscription', {})

function AutoHideSubscription:__init(owner, callback)
    self._active = true
    self._owner = owner
    self._callback = callback
end

---@return boolean
function AutoHideSubscription:is_active()
    return self._active
end

---@return boolean
function AutoHideSubscription:dispose()
    if not self._active then
        return false
    end
    self._active = false
    local owner = self._owner
    self._owner = nil
    self._callback = nil
    if owner then
        owner:_remove(self)
    end
    return true
end

---@class AutoHideController : std.object
---@field pointer_inside boolean
---@field _subscriptions AutoHideSubscription[]
---@overload fun(): self
local AutoHideController = std.class.new('AutoHideController', {})

function AutoHideController:__init()
    self.pointer_inside = false
    self._subscriptions = {}
end

---@param callback fun(event: AutoHideEvent)
---@return AutoHideSubscription
function AutoHideController:subscribe(callback)
    if type(callback) ~= 'function' then
        raise(std.TypeError('AutoHideController callback must be a function'))
    end
    local subscription = AutoHideSubscription(self, callback)
    self._subscriptions[#self._subscriptions + 1] = subscription
    return subscription
end

---@param subscription AutoHideSubscription
function AutoHideController:_remove(subscription)
    for index, current in ipairs(self._subscriptions) do
        if current == subscription then
            table.remove(self._subscriptions, index)
            return
        end
    end
end

---@param event AutoHideEvent
function AutoHideController:_emit(event)
    local subscriptions = {}
    for index, subscription in ipairs(self._subscriptions) do
        subscriptions[index] = subscription
    end
    for _, subscription in ipairs(subscriptions) do
        if subscription:is_active() then
            local callback = subscription._callback
            if callback then
                callback(event)
            end
        end
    end
end

function AutoHideController:pointer_move()
    self.pointer_inside = true
    self:_emit('move')
end

function AutoHideController:pointer_leave()
    self.pointer_inside = false
    self:_emit('leave')
end

---@param mode AutoHideMode
---@param event AutoHideEvent?
---@param pointer_inside boolean
---@return boolean
local function visible_for(mode, event, pointer_inside)
    if mode == 'always' then
        return true
    elseif mode == 'never' then
        return false
    elseif event == 'move' then
        return true
    elseif event == 'leave' then
        return false
    end
    return pointer_inside
end

---@class AutoHideState : State
---@field mode AutoHideMode
---@field visible boolean
---@field controls_visible boolean compatibility alias for player callers
---@field _controller AutoHideController
---@field _controller_subscription AutoHideSubscription?
---@overload fun(): self
local AutoHideState = std.class.new('AutoHideState', { State })

function AutoHideState:__init()
    std.super(AutoHideState, self, State).__init(self)
    self.mode = 'auto'
    self.visible = false
    self.controls_visible = false
    self._controller = nil
    self._controller_subscription = nil
end

---@param snapshot PlayerSnapshot?
---@param event AutoHideEvent?
function AutoHideState:_apply_snapshot(snapshot, event)
    local widget = self.widget --[[@as AutoHide]]
    local configured_mode = widget.mode
    local config = configured_mode and AutoHideConfig({ mode = configured_mode })
        or AutoHideConfig.from_snapshot(snapshot)
    self.mode = config.controls_visibility
    local next_visible = visible_for(
        self.mode, event, self._controller and self._controller.pointer_inside or false)
    self.visible = next_visible
    self.controls_visible = next_visible
end

function AutoHideState:_subscribe_controller(controller)
    self._controller = controller
    self._controller_subscription = controller:subscribe(function(event)
        if not self:is_mounted() then
            return
        end
        -- Events use a non-listening read. Provider dependency tracking belongs
        -- to build()/did_change_dependencies(), not to host callbacks.
        local context = self.context --[[@as BuildContext]]
        local provider = PlayerProvider.maybe_read(context)
        local snapshot = provider and provider.snapshot or nil
        local previous_visible = self.visible
        self:_apply_snapshot(snapshot, event)
        local visible = self.visible
        if previous_visible ~= visible then
            self:set_state()
        end
    end)
end

function AutoHideState:init_state()
    local widget = self.widget --[[@as AutoHide]]
    local context = self.context --[[@as BuildContext]]
    local provider = PlayerProvider.maybe_read(context)
    self:_apply_snapshot(provider and provider.snapshot or nil)
    self:_subscribe_controller(widget.controller)
end

function AutoHideState:did_change_dependencies()
    local context = self.context --[[@as BuildContext]]
    local provider = PlayerProvider.maybe_of(context)
    self:_apply_snapshot(provider and provider.snapshot or nil)
end

---@param old_widget StatefulWidget
function AutoHideState:did_update_widget(old_widget)
    local old_auto_hide = old_widget --[[@as AutoHide]]
    local auto_hide = self.widget --[[@as AutoHide]]
    if old_auto_hide.controller ~= auto_hide.controller then
        if self._controller_subscription then
            self._controller_subscription:dispose()
        end
        self:_subscribe_controller(auto_hide.controller)
    end
end

function AutoHideState:dispose()
    if self._controller_subscription then
        self._controller_subscription:dispose()
        self._controller_subscription = nil
    end
    self._controller = nil
end

---@param context BuildContext
---@return Widget?
function AutoHideState:build(context)
    local auto_hide = self.widget --[[@as AutoHide]]
    local provider = PlayerProvider.maybe_of(context)
    self:_apply_snapshot(provider and provider.snapshot or nil)
    if self.visible then
        return auto_hide.child
    end
    return nil
end

---@class _AutoHideOptions
---@field child Widget?
---@field controller AutoHideController?
---@field mode AutoHideMode?
---@field controls_visibility AutoHideMode? compatibility spelling
---@field key any?

---@class AutoHide : StatefulWidget
---@field child Widget?
---@field controller AutoHideController
---@field mode AutoHideMode?
---@overload fun(options?: _AutoHideOptions): self
local AutoHide = std.class.new('AutoHide', { StatefulWidget })

---@param options? _AutoHideOptions
function AutoHide:__init(options)
    options = options or {}
    if type(options) ~= 'table' then
        raise(std.TypeError('AutoHide expects an options table'))
    end
    local mode = options.mode
    if mode ~= nil and options.controls_visibility ~= nil and mode ~= options.controls_visibility then
        raise(std.ValueError('AutoHide mode values must agree'))
    end
    mode = mode or options.controls_visibility
    if mode ~= nil then
        mode = validate_mode(mode)
    end
    if options.controller ~= nil and not std.isinstance(options.controller, AutoHideController) then
        raise(std.TypeError('AutoHide.controller must be an AutoHideController'))
    end
    self.key = options.key
    self.child = options.child
    self.mode = mode
    self.controller = options.controller or AutoHideController()
end

function AutoHide:create_state()
    return AutoHideState()
end

function AutoHide:child_widgets()
    return self.child and { self.child } or {}
end

function AutoHide:bind_target()
    return 'child'
end

M.AutoHideConfig = AutoHideConfig
M.AutoHideSubscription = AutoHideSubscription
M.AutoHideController = AutoHideController
M.AutoHideState = AutoHideState
M.AutoHide = AutoHide

return M
