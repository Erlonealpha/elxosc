-- Explicit extension API; internal geometry/build helpers stay in their modules.
local app_mod = require 'src.widget.player.app'
local layout_mod = require 'src.widget.player.layout'
local theme_mod = require 'src.widget.player.theme'
local controls_mod = require 'src.widget.player.extension_controls'
local text_mod = require 'src.widget.player.text_controls'
local tooltip_mod = require 'src.widget.player.tooltip'
local timeline_mod = require 'src.widget.player.timeline'
local context_mod = require 'src.widget.player_context'
local actions_mod = require 'src.widget.actions'
local icon_mod = require 'src.widget.player.icon_map'

---@class elxosc.src.widget.player.components : elxosc.src.widget.player.theme, elxosc.src.widget.player.extension_controls, elxosc.src.widget.player.text_controls, elxosc.src.widget.player.tooltip, elxosc.src.widget.player.timeline
local M = {
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
    PlayerHoverText = text_mod.PlayerHoverText,
    PlayerTooltip = tooltip_mod.PlayerTooltip,
    Timeline = timeline_mod.Timeline,
    PlayerProvider = context_mod.PlayerProvider,
    PlayerCapability = context_mod.PlayerCapability,
    HostActions = actions_mod.HostActions,
    PlayerIcons = icon_mod,
}

return M
