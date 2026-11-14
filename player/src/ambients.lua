-- Explicit player, theme and action ambients above the generic framework.
local std = require 'elxlibs.std'
local text_style_mod = require 'src.text.text_style'
local widget_mod = require 'src.widget.widget'
local ambient_mod = require 'src.widget.ambient'
local WidgetsApp = require('src.widget.app').WidgetsApp
local player_theme_mod = require 'player.src.theme'
local actions_mod = require 'player.src.actions'
local layout_widgets = require 'src.widget.widgets.layout'

local TextStyle = text_style_mod.TextStyle
local StatelessWidget = widget_mod.StatelessWidget
local ThemeData = ambient_mod.ThemeData
local Theme = ambient_mod.Theme
local DisplaySnapshot = ambient_mod.DisplaySnapshot
local PlayerThemeData = player_theme_mod.PlayerThemeData
local PlayerTheme = player_theme_mod.PlayerTheme
local HostActions = actions_mod.HostActions
local HostActionsScope = actions_mod.HostActionsScope
local SizedBox = layout_widgets.SizedBox

local raise = std.raise

---@class elxosc.mod.player.src.ambients
local M = {}

local function child_or_empty(child)
    return child or SizedBox.shrink()
end

--== PlayerApp =============================================================

---@class elxosc.player._PlayerAppOptions
---@field child Widget?
---@field theme ThemeData?
---@field player_theme elxosc.player.PlayerThemeData?
---@field display DisplaySnapshot?
---@field default_text_style TextStyle?
---@field actions elxosc.player.HostActions?
---@field key any?

---@class elxosc.player.PlayerApp : StatelessWidget
---@field child Widget?
---@field theme ThemeData
---@field player_theme elxosc.player.PlayerThemeData
---@field display DisplaySnapshot
---@field default_text_style TextStyle
---@field actions elxosc.player.HostActions
---@overload fun(options?: elxosc.player._PlayerAppOptions): self
local PlayerApp = std.class.new('PlayerApp' --[[@as 'elxosc.player.PlayerApp']], StatelessWidget)

function PlayerApp:__init(options)
    options = options or {}
    self.key = options.key
    self.child = options.child
    self.theme = options.theme or ThemeData()
    self.player_theme = options.player_theme or PlayerThemeData()
    self.display = options.display or DisplaySnapshot({ width = 0, height = 0 })
    self.default_text_style = options.default_text_style or self.theme.text_style
    self.actions = options.actions or HostActions()
    if not std.isinstance(self.theme, ThemeData) then
        raise(std.TypeError('PlayerApp.theme must be ThemeData'))
    end
    if not std.isinstance(self.player_theme, PlayerThemeData) then
        raise(std.TypeError('PlayerApp.player_theme must be PlayerThemeData'))
    end
    if not std.isinstance(self.display, DisplaySnapshot) then
        raise(std.TypeError('PlayerApp.display must be DisplaySnapshot'))
    end
    if not std.isinstance(self.default_text_style, TextStyle) then
        raise(std.TypeError('PlayerApp.default_text_style must be TextStyle'))
    end
    if not std.isinstance(self.actions, HostActions) then
        raise(std.TypeError('PlayerApp.actions must be HostActions'))
    end
end

function PlayerApp:build()
    return Theme({
        data = self.theme,
        child = PlayerTheme({
            data = self.player_theme,
            child = HostActionsScope({
                actions = self.actions,
                child = WidgetsApp({
                    display = self.display,
                    default_text_style = self.default_text_style,
                    child = child_or_empty(self.child),
                }),
            }),
        }),
    })
end


M.PlayerApp = PlayerApp
return M
