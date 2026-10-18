-- Host-independent player Shell composition using the shared AutoHide widget.

local std = require 'elxlibs.std'
local autohide_mod = require 'widget.autohide'
local scaffold_mod = require 'player.scaffold'
local widget_mod = require 'widget.widget'

local AutoHideConfig = autohide_mod.AutoHideConfig
local AutoHideSubscription = autohide_mod.AutoHideSubscription
local AutoHideController = autohide_mod.AutoHideController
local AutoHideState = autohide_mod.AutoHideState
local AutoHide = autohide_mod.AutoHide
local State = require('widget.state').State
local StatefulWidget = widget_mod.StatefulWidget
local Main = scaffold_mod.Main
local Extension = scaffold_mod.Extension
local PlayerScaffold = scaffold_mod.PlayerScaffold

local raise = std.raise
local M = {}

-- Keep the player names as aliases of the one widget-level visibility
-- implementation. This lets existing host callers keep their API while
-- preventing PlayerShell from growing a second visibility state machine.
local ShellConfig = AutoHideConfig
local ShellVisibilitySubscription = AutoHideSubscription
local ShellVisibilityController = AutoHideController

---@alias ShellVisibilityController AutoHideController

---@class PlayerShellState : State
---@overload fun(): self
local PlayerShellState = std.class.new('PlayerShellState', { State })

function PlayerShellState:__init()
    std.super(PlayerShellState, self, State).__init(self)
end

---@param context BuildContext
---@return PlayerScaffold
function PlayerShellState:build(context)
    local shell = self.widget --[[@as PlayerShell]]
    local source = shell.scaffold
    local source_main = source.main
    local main = Main({
        key = source_main and source_main.key or nil,
        left = source_main and source_main.left or shell.left,
        right = source_main and source_main.right or shell.right,
        title_bar = shell.title_bar,
        timeline = shell.timeline,
        bottom = shell.bottom,
    })
    local extension = source.extension or Extension({
        grid = source.grid,
        more = source.more,
    })
    return PlayerScaffold({
        key = source.key,
        main = AutoHide({
            key = 'player-controls-autohide',
            child = main,
            controller = shell.controller,
        }),
        extension = extension,
        grid = source.grid,
        more = source.more,
    })
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
M.AutoHideConfig = AutoHideConfig
M.AutoHideController = AutoHideController
M.AutoHideState = AutoHideState
M.AutoHide = AutoHide
M.PlayerShellState = PlayerShellState
M.PlayerShell = PlayerShell

return M
