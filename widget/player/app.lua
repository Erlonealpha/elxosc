-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Default player shell widgets.  The generic WidgetsApp ambient wrapper stays
-- in widget/app.lua; this module owns Main, AutoHide and WindowLayer composition.

local std = require 'elxlibs.std'
local geometry = require 'foundation.geometry'
local widget_mod = require 'widget.widget'
local ambient_mod = require 'widget.ambient'
local actions_mod = require 'widget.actions'
local overlay_mod = require 'widget.overlay'
local visibility_mod = require 'widget.visibility'
local layout_widgets = require 'widget.widgets.layout'
local player_context = require 'widget.player_context'
local player_theme_mod = require 'widget.player.theme'
local player_layout_mod = require 'widget.player.layout'
local metadata_mod = require 'widget.player.metadata'

local EdgeInsets = geometry.EdgeInsets
local Offset = geometry.Offset
local Size = geometry.Size
local StatelessWidget = widget_mod.StatelessWidget
local StatefulWidget = widget_mod.StatefulWidget
local State = require('widget.state').State
local ThemeData = ambient_mod.ThemeData
local Theme = ambient_mod.Theme
local HostActions = actions_mod.HostActions
local PlayerProvider = player_context.PlayerProvider
local PlayerThemeData = player_theme_mod.PlayerThemeData
local PlayerTheme = player_theme_mod.PlayerTheme
local PlayerLayout = player_layout_mod.PlayerLayout
local player_title = metadata_mod.title
local OverlayEntry = overlay_mod.OverlayEntry
local Theatre = overlay_mod.Theatre
local AutoHide = visibility_mod.AutoHide
local AutoHideController = visibility_mod.AutoHideController
local SizedBox = layout_widgets.SizedBox
local LayoutScaleBox = layout_widgets.LayoutScaleBox

local raise = std.raise
local M = {}

---@alias WindowTopBarMode
---| 'auto'
---| 'yes'
---| 'no'

local function child_or_empty(child)
    return child or SizedBox.shrink()
end

--== Main ===================================================================

---@class _MainOptions
---@field title string?
---@field title_bar Widget?
---@field window_controls Widget?
---@field window_top_bar WindowTopBarMode?
---@field layout_option PlayerLayoutOption?
---@field bottom Widget?
---@field scale number?
---@field key any?

---@class Main : StatelessWidget
---@field title string
---@field title_bar Widget?
---@field window_controls Widget?
---@field window_top_bar WindowTopBarMode?
---@field layout_option PlayerLayoutOption?
---@field bottom Widget?
---@field scale number?
---@overload fun(options?: _MainOptions): self
local Main = std.class.new('Main', { StatelessWidget })

function Main:__init(options)
    options = options or {}
    self.key = options.key
    self.title = options.title or 'elxosc'
    self.title_bar = options.title_bar
    self.window_controls = options.window_controls
    self.window_top_bar = options.window_top_bar
    if self.window_top_bar ~= nil and self.window_top_bar ~= 'auto' and self.window_top_bar ~= 'yes'
        and self.window_top_bar ~= 'no' then
        raise(std.ValueError('Main.window_top_bar must be auto, yes or no'))
    end
    self.layout_option = options.layout_option
    if self.layout_option ~= nil and self.layout_option ~= 'original'
        and self.layout_option ~= 'reduced' then
        raise(std.ValueError('Main.layout_option must be original or reduced'))
    end
    self.bottom = options.bottom
    self.scale = options.scale
end

function Main:child_widgets()
    local children = {}
    if self.title_bar then
        children[#children + 1] = self.title_bar
    end
    if self.window_controls then
        children[#children + 1] = self.window_controls
    end
    if self.bottom then
        children[#children + 1] = self.bottom
    end
    return children
end

local function top_hover_enabled(snapshot)
    if snapshot == nil then
        return true
    end
    local fullscreen = snapshot:get('fullscreen')
    local border = snapshot:get('border')
    local title_bar = snapshot:get('title_bar')
    if fullscreen == true or border == false or title_bar == false then
        return true
    end
    if fullscreen ~= nil and border ~= nil and title_bar ~= nil then
        return false
    end
    return true
end

---@param snapshot PlayerSnapshot?
---@param mode WindowTopBarMode
---@return boolean
local function top_bar_visible(snapshot, mode)
    if mode == 'yes' then
        return true
    end
    if mode == 'no' then
        return false
    end
    return top_hover_enabled(snapshot)
end

---@param context BuildContext
function Main:build(context)
    local theme_scope = Theme.maybe_of(context)
    local theme = theme_scope and theme_scope.data or ThemeData()
    local player_theme_scope = PlayerTheme.maybe_of(context)
    local player_theme = player_theme_scope and player_theme_scope.data or PlayerThemeData()
    local actions = HostActions.maybe_of(context) or HostActions()
    local player = PlayerProvider.maybe_of(context)
    local snapshot = player and player.snapshot or nil
    local mode = self.window_top_bar or player_theme.window_top_bar
    local scale = self.scale or theme.scale
    return LayoutScaleBox(PlayerLayout({
        theme = player_theme,
        actions = actions,
        snapshot = snapshot,
        title = player_title(snapshot, self.title),
        title_bar = self.title_bar,
        window_controls = self.window_controls,
        bottom = self.bottom,
        layout_option = self.layout_option or player_theme.layout_option,
        top_bar_visible = top_bar_visible(snapshot, mode),
        scale = scale,
    }), {
        scale = Size(scale, scale),
        alignment = Offset(0.5, 1),
        clip = true,
    })
end

--== WindowLayer ============================================================

---@class _WindowLayerOptions
---@field child Widget?
---@field key any?

---@class WindowLayer : StatelessWidget
---@field child Widget?
---@overload fun(options?: _WindowLayerOptions): self
local WindowLayer = std.class.new('WindowLayer', { StatelessWidget })

function WindowLayer:__init(options)
    options = options or {}
    self.key = options.key
    self.child = options.child
end

function WindowLayer:child_widgets()
    return self.child and { self.child } or {}
end

function WindowLayer:build()
    return child_or_empty(self.child)
end

--== DefaultApp =============================================================

---@class _DefaultAppOptions
---@field main Widget?
---@field extension Widget?
---@field window_layer Widget?
---@field title string?
---@field scale number?
---@field auto_hide_timeout number?
---@field auto_hide_enabled boolean?
---@field auto_hide_fade_duration number?
---@field auto_hide_bottom_hover boolean?
---@field auto_hide_hover_zone number?
---@field auto_hide_top_hover boolean?
---@field auto_hide_top_hover_enabled boolean?
---@field auto_hide_top_hover_zone number?
---@field auto_hide_controller AutoHideController?
---@field key any?

---@class DefaultApp : StatefulWidget
---@field main Widget?
---@field extension Widget?
---@field window_layer Widget?
---@field title string
---@field scale number?
---@field auto_hide_timeout number
---@field auto_hide_enabled boolean
---@field auto_hide_fade_duration number
---@field auto_hide_bottom_hover boolean
---@field auto_hide_hover_zone number
---@field auto_hide_top_hover boolean
---@field auto_hide_top_hover_enabled boolean?
---@field auto_hide_top_hover_zone number
---@field auto_hide_controller AutoHideController
---@overload fun(options?: _DefaultAppOptions): self
local DefaultApp = std.class.new('DefaultApp', { StatefulWidget })

function DefaultApp:__init(options)
    options = options or {}
    self.key = options.key
    self.main = options.main
    self.extension = options.extension
    self.window_layer = options.window_layer
    self.title = options.title or 'elxosc'
    self.scale = options.scale
    -- ModernX hide_timeout defaults to 1500ms; keeping the player visible for
    -- three seconds makes hover scale appear to collapse at an unrelated time.
    self.auto_hide_timeout = options.auto_hide_timeout == nil and 1.5 or options.auto_hide_timeout
    self.auto_hide_enabled = options.auto_hide_enabled ~= false
    self.auto_hide_fade_duration = options.auto_hide_fade_duration == nil and 0.15
        or options.auto_hide_fade_duration
    self.auto_hide_bottom_hover = options.auto_hide_bottom_hover == true
    self.auto_hide_hover_zone = options.auto_hide_hover_zone == nil and 175
        or options.auto_hide_hover_zone
    self.auto_hide_top_hover = options.auto_hide_top_hover == true
    self.auto_hide_top_hover_enabled = options.auto_hide_top_hover_enabled
    if self.auto_hide_top_hover_enabled ~= nil
        and type(self.auto_hide_top_hover_enabled) ~= 'boolean' then
        raise(std.TypeError('DefaultApp.auto_hide_top_hover_enabled must be a boolean'))
    end
    self.auto_hide_top_hover_zone = options.auto_hide_top_hover_zone == nil and 40
        or options.auto_hide_top_hover_zone
    self.auto_hide_controller = options.auto_hide_controller or AutoHideController()
    if not std.isinstance(self.auto_hide_controller, AutoHideController) then
        raise(std.TypeError('DefaultApp.auto_hide_controller must be an AutoHideController'))
    end
end

function DefaultApp:child_widgets()
    local children = {}
    if self.main then
        children[#children + 1] = self.main
    end
    if self.extension then
        children[#children + 1] = self.extension
    end
    if self.window_layer then
        children[#children + 1] = self.window_layer
    end
    return children
end

---@class DefaultAppState : State
---@field main_controller AutoHideController
---@field main_entry OverlayEntry
---@field extension_entry OverlayEntry
---@field window_entry OverlayEntry
---@overload fun(): self
local DefaultAppState = std.class.new('DefaultAppState', { State })

function DefaultAppState:__init()
    std.super(DefaultAppState, self, State).__init(self)
    self.main_controller = nil
    self.main_entry = nil
    self.extension_entry = nil
    self.window_entry = nil
end

function DefaultAppState:init_state()
    local app = self.widget --[[@as DefaultApp]]
    self.main_controller = app.auto_hide_controller
    self.extension_entry = OverlayEntry({
        key = 'default-app-extension',
        builder = function()
            local current_app = self.widget --[[@as DefaultApp]]
            return current_app.extension
        end,
    })
    self.main_entry = OverlayEntry({
        key = 'default-app-main',
        builder = function(context)
            local current_app = self.widget --[[@as DefaultApp]]
            local main = current_app.main
                or Main({ title = current_app.title, scale = current_app.scale })
            local player = PlayerProvider.maybe_of(context)
            local snapshot = player and player.snapshot or nil
            local theme_scope = Theme.maybe_of(context)
            local theme = theme_scope and theme_scope.data or ThemeData()
            local main_scale = std.isinstance(main, Main) and (main.scale or theme.scale) or 1
            local top_enabled = current_app.auto_hide_top_hover_enabled
            if top_enabled == nil then
                local player_theme_scope = PlayerTheme.maybe_of(context)
                local player_theme = player_theme_scope and player_theme_scope.data or PlayerThemeData()
                local mode = std.isinstance(main, Main) and main.window_top_bar
                    or player_theme.window_top_bar
                mode = mode or 'auto'
                top_enabled = top_bar_visible(snapshot, mode)
            end
            return AutoHide({
                controller = self.main_controller,
                timeout = current_app.auto_hide_timeout,
                enabled = current_app.auto_hide_enabled,
                fade_duration = current_app.auto_hide_fade_duration,
                bottom_hover = current_app.auto_hide_bottom_hover,
                hover_zone = current_app.auto_hide_hover_zone * main_scale,
                top_hover = current_app.auto_hide_top_hover,
                top_hover_enabled = top_enabled,
                top_hover_zone = current_app.auto_hide_top_hover_zone * main_scale,
                child = main,
            })
        end,
    })
    self.window_entry = OverlayEntry({
        key = 'default-app-window-layer',
        builder = function()
            local current_app = self.widget --[[@as DefaultApp]]
            return current_app.window_layer or WindowLayer()
        end,
    })
end

function DefaultAppState:did_update_widget(old_widget)
    local app = self.widget --[[@as DefaultApp]]
    self.main_controller = app.auto_hide_controller
    if self.main_entry then
        self.main_entry:mark_needs_build()
    end
    if self.extension_entry then
        self.extension_entry:mark_needs_build()
    end
    if self.window_entry then
        self.window_entry:mark_needs_build()
    end
end

function DefaultAppState:build()
    return Theatre({
        initial_entries = {
            self.extension_entry,
            self.main_entry,
            self.window_entry,
        },
    })
end

function DefaultAppState:set_main_visible(visible)
    return self.main_controller:set_visible(visible)
end

function DefaultAppState:show_main()
    return self.main_controller:show()
end

function DefaultAppState:hide_main()
    return self.main_controller:hide()
end

function DefaultAppState:notify_activity(x, y, viewport)
    self.main_controller:activity(x, y, viewport)
end

function DefaultApp:create_state()
    return DefaultAppState()
end

M.Main = Main
M.WindowLayer = WindowLayer
M.DefaultApp = DefaultApp
M.DefaultAppState = DefaultAppState

return M
