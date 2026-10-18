-- Host-independent player Shell with Provider-driven control visibility.

local std = require 'elxlibs.std'
local player_context = require 'widget.player_context'
local scaffold_mod = require 'player.scaffold'
local widget_mod = require 'widget.widget'

local PlayerProvider = player_context.PlayerProvider
local State = require('widget.state').State
local StatefulWidget = widget_mod.StatefulWidget
local PlayerScaffold = scaffold_mod.PlayerScaffold

local raise = std.raise
local M = {}

---@alias ControlsVisibilityMode
---| 'auto'
---| 'always'
---| 'never'

---@class ShellConfigOptions
---@field controls_visibility ControlsVisibilityMode?

---@class ShellConfig : std.object
---@field controls_visibility ControlsVisibilityMode
---@overload fun(options?: ShellConfigOptions): self
local ShellConfig = std.class.new('ShellConfig', {})

local VALID_MODES = {
    auto = true,
    always = true,
    never = true,
}

---@param value any
---@return ControlsVisibilityMode
local function validate_mode(value)
    if type(value) ~= 'string' or not VALID_MODES[value] then
        raise(std.ValueError(
            'controls_visibility must be auto, always, or never'))
    end
    return value --[[@as ControlsVisibilityMode]]
end

---@param value any
---@return ControlsVisibilityMode
local function normalize_mode(value)
    if value == nil then
        return 'auto'
    end
    return validate_mode(value)
end

function ShellConfig:__init(options)
    options = options or {}
    if type(options) ~= 'table' then
        raise(std.TypeError('ShellConfig expects an options table'))
    end
    self.controls_visibility = normalize_mode(options.controls_visibility)
end

---@param snapshot PlayerSnapshot?
---@return ShellConfig
function ShellConfig.from_snapshot(snapshot)
    if snapshot == nil then
        return ShellConfig()
    end
    local mode = snapshot:get('controls_visibility') --[[@as ControlsVisibilityMode?]]
    return ShellConfig({ controls_visibility = mode })
end

---@class ShellVisibilitySubscription : std.object
---@field _active boolean
---@field _owner ShellVisibilityController?
---@field _callback fun(event: 'move'|'leave')?
---@overload fun(owner: ShellVisibilityController, callback: fun(event: 'move'|'leave')): self
local ShellVisibilitySubscription = std.class.new('ShellVisibilitySubscription', {})

function ShellVisibilitySubscription:__init(owner, callback)
    self._active = true
    self._owner = owner
    self._callback = callback
end

---@return boolean
function ShellVisibilitySubscription:is_active()
    return self._active
end

---@return boolean
function ShellVisibilitySubscription:dispose()
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

---@class ShellVisibilityController : std.object
---@field pointer_inside boolean
---@field _subscriptions ShellVisibilitySubscription[]
---@overload fun(): self
local ShellVisibilityController = std.class.new('ShellVisibilityController', {})

function ShellVisibilityController:__init()
    self.pointer_inside = false
    self._subscriptions = {}
end

---@param callback fun(event: 'move'|'leave')
---@return ShellVisibilitySubscription
function ShellVisibilityController:subscribe(callback)
    if type(callback) ~= 'function' then
        raise(std.TypeError('ShellVisibilityController callback must be a function'))
    end
    local subscription = ShellVisibilitySubscription(self, callback)
    self._subscriptions[#self._subscriptions + 1] = subscription
    return subscription
end

---@param subscription ShellVisibilitySubscription
function ShellVisibilityController:_remove(subscription)
    for index, current in ipairs(self._subscriptions) do
        if current == subscription then
            table.remove(self._subscriptions, index)
            return
        end
    end
end

---@param event 'move'|'leave'
function ShellVisibilityController:_emit(event)
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

function ShellVisibilityController:pointer_move()
    self.pointer_inside = true
    self:_emit('move')
end

function ShellVisibilityController:pointer_leave()
    self.pointer_inside = false
    self:_emit('leave')
end

---@class _PlayerShellOptions
---@field scaffold PlayerScaffold
---@field title_bar Widget?
---@field timeline Widget?
---@field bottom Widget?
---@field left Widget?
---@field right Widget?
---@field controller ShellVisibilityController?
---@field key any?

---@class PlayerShellState : State
---@field mode ControlsVisibilityMode
---@field controls_visible boolean
---@field _controller ShellVisibilityController
---@field _controller_subscription ShellVisibilitySubscription?
---@overload fun(): self
local PlayerShellState = std.class.new('PlayerShellState', { State })

function PlayerShellState:__init()
    std.super(PlayerShellState, self, State).__init(self)
    self.mode = 'auto'
    self.controls_visible = false
    self._controller = nil
    self._controller_subscription = nil
end

---@param mode ControlsVisibilityMode
---@param event 'move'|'leave'?
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

---@param snapshot PlayerSnapshot?
---@param event 'move'|'leave'?
function PlayerShellState:_apply_snapshot(snapshot, event)
    local config = ShellConfig.from_snapshot(snapshot)
    self.mode = config.controls_visibility
    self.controls_visible = visible_for(
        self.mode, event, self._controller and self._controller.pointer_inside or false)
end

function PlayerShellState:_subscribe_controller(controller)
    self._controller = controller
    self._controller_subscription = controller:subscribe(function(event)
        if not self:is_mounted() then
            return
        end
        -- Event callbacks deliberately use a non-listening read. The current
        -- snapshot, rather than a captured build value, decides the policy.
        local context = self.context --[[@as BuildContext]]
        local provider = PlayerProvider.maybe_read(context)
        local snapshot = provider and provider.snapshot or nil
        local previous_visible = self.controls_visible
        self:_apply_snapshot(snapshot, event)
        local controls_visible = self.controls_visible
        if previous_visible ~= controls_visible then
            self:set_state()
        end
    end)
end

function PlayerShellState:init_state()
    local widget = self.widget --[[@as PlayerShell]]
    local context = self.context --[[@as BuildContext]]
    local provider = PlayerProvider.maybe_read(context)
    self:_apply_snapshot(provider and provider.snapshot or nil)
    self:_subscribe_controller(widget.controller or ShellVisibilityController())
end

function PlayerShellState:did_change_dependencies()
    local context = self.context --[[@as BuildContext]]
    local provider = PlayerProvider.maybe_of(context)
    self:_apply_snapshot(provider and provider.snapshot or nil)
end

---@param old_widget StatefulWidget
function PlayerShellState:did_update_widget(old_widget)
    local old_shell = old_widget --[[@as PlayerShell]]
    local shell = self.widget --[[@as PlayerShell]]
    if old_shell.controller ~= shell.controller then
        if self._controller_subscription then
            self._controller_subscription:dispose()
        end
        self:_subscribe_controller(shell.controller or ShellVisibilityController())
    end
end

function PlayerShellState:dispose()
    if self._controller_subscription then
        self._controller_subscription:dispose()
        self._controller_subscription = nil
    end
    self._controller = nil
end

---@param visible boolean
---@return PlayerScaffold
function PlayerShellState:_scaffold(visible)
    local shell = self.widget --[[@as PlayerShell]]
    local source = shell.scaffold
    local source_main = source.main
    return PlayerScaffold({
        key = source.key,
        grid = source.grid,
        more = source.more,
        main_left = visible and ((source_main and source_main.left) or shell.left) or nil,
        main_right = visible and ((source_main and source_main.right) or shell.right) or nil,
        title_bar = visible and shell.title_bar or nil,
        timeline = visible and shell.timeline or nil,
        bottom = visible and shell.bottom or nil,
    })
end

---@param context BuildContext
---@return Widget
function PlayerShellState:build(context)
    -- Listening lookup belongs in build so a PlayerStore replacement rebuilds
    -- the same Shell State instead of remounting the root.
    local provider = PlayerProvider.maybe_of(context)
    local config = ShellConfig.from_snapshot(provider and provider.snapshot or nil)
    local visible = visible_for(
        config.controls_visibility, nil,
        self._controller and self._controller.pointer_inside or false)
    self.mode = config.controls_visibility
    self.controls_visible = visible
    return self:_scaffold(visible)
end

---@class PlayerShell : StatefulWidget
---@field scaffold PlayerScaffold
---@field title_bar Widget?
---@field timeline Widget?
---@field bottom Widget?
---@field left Widget?
---@field right Widget?
---@field controller ShellVisibilityController
---@overload fun(options: _PlayerShellOptions): self
local PlayerShell = std.class.new('PlayerShell', { StatefulWidget })

---@param options _PlayerShellOptions
function PlayerShell:__init(options)
    if type(options) ~= 'table' then
        raise(std.TypeError('PlayerShell expects an options table'))
    end
    if type(options.scaffold) ~= 'table' then
        raise(std.TypeError('PlayerShell.scaffold must be a PlayerScaffold'))
    end
    if options.controller ~= nil and not std.isinstance(options.controller, ShellVisibilityController) then
        raise(std.TypeError('PlayerShell.controller must be a ShellVisibilityController'))
    end
    self.key = options.key
    self.scaffold = options.scaffold
    self.title_bar = options.title_bar
    self.timeline = options.timeline
    self.bottom = options.bottom
    self.left = options.left
    self.right = options.right
    self.controller = options.controller or ShellVisibilityController()
end

function PlayerShell:create_state()
    return PlayerShellState()
end

M.ShellConfig = ShellConfig
M.ShellVisibilitySubscription = ShellVisibilitySubscription
M.ShellVisibilityController = ShellVisibilityController
M.PlayerShellState = PlayerShellState
M.PlayerShell = PlayerShell

return M
