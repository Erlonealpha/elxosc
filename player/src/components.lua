-- Explicit extension API; internal geometry/build helpers stay in their modules.
---@namespace elxosc
---@using elxosc
---@using elxosc.player

local app_mod = require 'player.src.app'
local layout_mod = require 'player.src.layout'
local theme_mod = require 'player.src.theme'
local controls_mod = require 'player.src.extension_controls'
local text_mod = require 'player.src.text_controls'
local tooltip_mod = require 'player.src.tooltip'
local timeline_mod = require 'player.src.timeline'
local context_mod = require 'player.src.context'
local actions_mod = require 'player.src.actions'
local icon_mod = require 'player.src.icon_map'
local auto_hide_mod = require 'player.src.auto_hide'
local ambients_mod = require 'player.src.ambients'

---@class mod.player.src.components : mod.player.src.theme, mod.player.src.extension_controls, mod.player.src.text_controls, mod.player.src.tooltip, mod.player.src.timeline
local M = {
    Main = app_mod.Main,
    PlayerApp = ambients_mod.PlayerApp,
    PlayerMain = app_mod.Main,
    WindowLayer = app_mod.WindowLayer,
    DefaultApp = app_mod.DefaultApp,
    PlayerLayout = layout_mod.PlayerLayout,
    PlayerDescriptionLayer = layout_mod.PlayerDescriptionLayer,
    PlayerTheme = theme_mod.PlayerTheme,
    PlayerThemeData = theme_mod.PlayerThemeData,
    PlayerControlBar = controls_mod.PlayerControlBar,
    PlayerControlButton = controls_mod.PlayerControlButton,
    PlayerTimeDisplay = text_mod.PlayerTimeDisplay,
    PlayerTimeWidth = text_mod.PlayerTimeWidth,
    PlayerHoverText = text_mod.PlayerHoverText,
    PlayerTooltip = tooltip_mod.PlayerTooltip,
    PlayerTimeTooltip = tooltip_mod.PlayerTimeTooltip,
    Timeline = timeline_mod.Timeline,
    PlayerProvider = context_mod.PlayerProvider,
    PlayerCapability = context_mod.PlayerCapability,
    HostActions = actions_mod.HostActions,
    HostActionsScope = actions_mod.HostActionsScope,
    PlayerSnapshot = context_mod.PlayerSnapshot,
    PlayerSubscription = context_mod.PlayerSubscription,
    PlayerStore = context_mod.PlayerStore,
    PlayerScope = context_mod.PlayerScope,
    AutoHide = auto_hide_mod.AutoHide,
    AutoHideController = auto_hide_mod.AutoHideController,
    PlayerIcons = icon_mod,
}

return M
