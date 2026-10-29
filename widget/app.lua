-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Generic application ambient wrapper and compatibility aggregate for the
-- default player modules in widget/player/.
--
-- WidgetsApp supplies framework ambients. Player shell composition is owned by
-- widget/player/app.lua; this module re-exports those classes for compatibility.

local std = require 'elxlibs.std'
local text_style_mod = require 'text.text_style'
local widget_mod = require 'widget.widget'
local ambient_mod = require 'widget.ambient'
local player_theme_mod = require 'widget.player.theme'
local actions_mod = require 'widget.actions'
local layout_widgets = require 'widget.widgets.layout'

local TextStyle = text_style_mod.TextStyle
local StatelessWidget = widget_mod.StatelessWidget
local ThemeData = ambient_mod.ThemeData
local Theme = ambient_mod.Theme
local DisplaySnapshot = ambient_mod.DisplaySnapshot
local DisplayScope = ambient_mod.DisplayScope
local DefaultTextStyle = ambient_mod.DefaultTextStyle
local PlayerThemeData = player_theme_mod.PlayerThemeData
local PlayerTheme = player_theme_mod.PlayerTheme
local HostActions = actions_mod.HostActions
local HostActionsScope = actions_mod.HostActionsScope
local SizedBox = layout_widgets.SizedBox

local raise = std.raise

local M = {}

local function child_or_empty(child)
    return child or SizedBox.shrink()
end

--== WidgetsApp =============================================================

---@class _WidgetsAppOptions
---@field child Widget?
---@field theme ThemeData?
---@field player_theme PlayerThemeData?
---@field display DisplaySnapshot?
---@field default_text_style TextStyle?
---@field actions HostActions?
---@field key any?

---@class WidgetsApp : StatelessWidget
---@field child Widget?
---@field theme ThemeData
---@field player_theme PlayerThemeData
---@field display DisplaySnapshot
---@field default_text_style TextStyle
---@field actions HostActions
---@overload fun(options?: _WidgetsAppOptions): self
local WidgetsApp = std.class.new('WidgetsApp', { StatelessWidget })

function WidgetsApp:__init(options)
    options = options or {}
    self.key = options.key
    self.child = options.child
    self.theme = options.theme or ThemeData()
    self.player_theme = options.player_theme or PlayerThemeData()
    self.display = options.display or DisplaySnapshot({ width = 0, height = 0 })
    self.default_text_style = options.default_text_style or self.theme.text_style
    self.actions = options.actions or HostActions()
    if not std.isinstance(self.theme, ThemeData) then
        raise(std.TypeError('WidgetsApp.theme must be ThemeData'))
    end
    if not std.isinstance(self.player_theme, PlayerThemeData) then
        raise(std.TypeError('WidgetsApp.player_theme must be PlayerThemeData'))
    end
    if not std.isinstance(self.display, DisplaySnapshot) then
        raise(std.TypeError('WidgetsApp.display must be DisplaySnapshot'))
    end
    if not std.isinstance(self.default_text_style, TextStyle) then
        raise(std.TypeError('WidgetsApp.default_text_style must be TextStyle'))
    end
    if not std.isinstance(self.actions, HostActions) then
        raise(std.TypeError('WidgetsApp.actions must be HostActions'))
    end
end

function WidgetsApp:build()
    return Theme({
        data = self.theme,
        child = PlayerTheme({
            data = self.player_theme,
            child = DisplayScope({
                snapshot = self.display,
                child = DefaultTextStyle({
                    style = self.default_text_style,
                    child = HostActionsScope({
                        actions = self.actions,
                        child = child_or_empty(self.child),
                    }),
                }),
            }),
        }),
    })
end

-- Compatibility aggregate: player components now live in widget/player/.
M.WidgetsApp = WidgetsApp
M.PlayerThemeData = PlayerThemeData
M.PlayerTheme = PlayerTheme
local player_app = require 'widget.player.app'
for name, value in pairs(player_app) do
    M[name] = value
end

return M
