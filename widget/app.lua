-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Application composition for the first default player slice.
--
-- WidgetsApp supplies framework ambients.  DefaultApp owns the player-level
-- composition and installs one Theatre containing stable Main, Extension and
-- WindowLayer entries.  Main visibility is therefore independent from the
-- Extension entry and never requires a second runtime root.

local std = require 'elxlibs.std'
local color_mod = require 'foundation.color'
local geometry = require 'foundation.geometry'
local text_style_mod = require 'text.text_style'
local widget_mod = require 'widget.widget'
local ambient_mod = require 'widget.ambient'
local actions_mod = require 'widget.actions'
local overlay_mod = require 'widget.overlay'
local visibility_mod = require 'widget.visibility'
local layout_widgets = require 'widget.widgets.layout'
local basic_widgets = require 'widget.widgets.basic'
local player_context = require 'widget.player_context'

local Color = color_mod.Color
local EdgeInsets = geometry.EdgeInsets
local Offset = geometry.Offset
local Size = geometry.Size
local TextStyle = text_style_mod.TextStyle
local StatelessWidget = widget_mod.StatelessWidget
local StatefulWidget = widget_mod.StatefulWidget
local State = require('widget.state').State
local ThemeData = ambient_mod.ThemeData
local Theme = ambient_mod.Theme
local DisplaySnapshot = ambient_mod.DisplaySnapshot
local DisplayScope = ambient_mod.DisplayScope
local DefaultTextStyle = ambient_mod.DefaultTextStyle
local HostActions = actions_mod.HostActions
local HostActionsScope = actions_mod.HostActionsScope
local OverlayEntry = overlay_mod.OverlayEntry
local Theatre = overlay_mod.Theatre
local AutoHide = visibility_mod.AutoHide
local AutoHideController = visibility_mod.AutoHideController
local Container = layout_widgets.Container
local Column = layout_widgets.Column
local Row = layout_widgets.Row
local Expanded = layout_widgets.Expanded
local Stack = layout_widgets.Stack
local SizedBox = layout_widgets.SizedBox
local LayoutScaleBox = layout_widgets.LayoutScaleBox
local Text = basic_widgets.Text
local TextButton = basic_widgets.TextButton

local raise = std.raise

local M = {}

local function child_or_empty(child)
    return child or SizedBox.shrink()
end

--== WidgetsApp =============================================================

---@class _WidgetsAppOptions
---@field child Widget?
---@field theme ThemeData?
---@field display DisplaySnapshot?
---@field default_text_style TextStyle?
---@field actions HostActions?
---@field key any?

---@class WidgetsApp : StatelessWidget
---@field child Widget?
---@field theme ThemeData
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
    self.display = options.display or DisplaySnapshot({ width = 0, height = 0 })
    self.default_text_style = options.default_text_style or self.theme.text_style
    self.actions = options.actions or HostActions()
    if not std.isinstance(self.theme, ThemeData) then
        raise(std.TypeError('WidgetsApp.theme must be ThemeData'))
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
    })
end

--== Main ===================================================================

---@class _MainOptions
---@field title string?
---@field title_bar Widget?
---@field window_controls Widget?
---@field bottom Widget?
---@field scale number?
---@field key any?

---@class Main : StatelessWidget
---@field title string
---@field title_bar Widget?
---@field window_controls Widget?
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

local function snapshot_text(snapshot, names, fallback)
    if snapshot then
        for _, name in ipairs(names) do
            local value = snapshot:get(name)
            if value ~= nil and tostring(value) ~= '' then
                return tostring(value)
            end
        end
    end
    return fallback
end

function Main:_default_title_bar(theme)
    return Container({
        padding = EdgeInsets.symmetric(10, 6),
        color = theme.surface_color,
        child = Text(self.title, {
            style = theme.text_style:copy_with({ bold = true, font_size = theme.text_style.font_size + 1 }),
        }),
    })
end

function Main:_default_window_controls(actions, theme)
    local font_size = math.max(11, theme.text_style.font_size - 1)
    return Row({
        spacing = 4,
        children = {
            TextButton({ label = '−', font_size = font_size, on_click = function()
                actions:minimize()
            end }),
            TextButton({ label = '□', font_size = font_size, on_click = function()
                actions:toggle_fullscreen()
            end }),
            TextButton({ label = '×', font_size = font_size, on_click = function()
                actions:close()
            end }),
        },
    })
end

function Main:_default_bottom(actions, theme, snapshot)
    local label_style = theme.text_style:copy_with({ font_size = math.max(11, theme.text_style.font_size - 2) })
    local title = snapshot_text(snapshot, { 'media_title', 'title', 'filename' }, self.title)
    local info = snapshot_text(snapshot, { 'media_size', 'file_size' }, 'ready')
    local position = snapshot_text(snapshot, { 'time_pos', 'position' }, '00:00')
    local duration = snapshot_text(snapshot, { 'duration', 'time_duration' }, '--:--')
    return Column({
        main_axis_size = 'min',
        cross_alignment = 'stretch',
        children = {
            Container({
                padding = EdgeInsets.symmetric(10, 2),
                color = theme.surface_color,
                child = Text(title, { style = label_style }),
            }),
            Container({
                padding = EdgeInsets.symmetric(10, 2),
                child = Text(info, { style = label_style }),
            }),
            Container({
                height = 4,
                color = theme.accent_color,
            }),
            Container({
                padding = EdgeInsets.symmetric(10, 2),
                child = Row({
                    main_axis_size = 'max',
                    children = {
                        Text(position, { style = label_style }),
                        Expanded(SizedBox.shrink()),
                        Text(duration, { style = label_style }),
                    },
                }),
            }),
            Container({
                padding = EdgeInsets.symmetric(8, 3),
                color = theme.surface_color,
                child = Row({
                    spacing = 6,
                    main_alignment = 'center',
                    children = {
                        TextButton({ label = 'Play', on_click = function() actions:play_pause() end }),
                        TextButton({ label = '−10', on_click = function() actions:seek(-10) end }),
                        TextButton({ label = '+10', on_click = function() actions:seek(10) end }),
                    },
                }),
            }),
        },
    })
end

---@param context BuildContext
function Main:build(context)
    local theme_scope = Theme.maybe_of(context)
    local theme = theme_scope and theme_scope.data or ThemeData()
    local actions = HostActions.maybe_of(context) or HostActions()
    local player = player_context.PlayerProvider.maybe_of(context)
    local snapshot = player and player.snapshot or nil
    local title_bar = self.title_bar or self:_default_title_bar(theme)
    local window_controls = self.window_controls or self:_default_window_controls(actions, theme)
    local bottom = self.bottom or self:_default_bottom(actions, theme, snapshot)
    local scale = self.scale or theme.scale

    return LayoutScaleBox(Column({
        main_axis_size = 'max',
        cross_alignment = 'stretch',
        children = {
            Container({
                height = 42,
                color = theme.surface_color,
                child = Row({
                    main_axis_size = 'max',
                    cross_alignment = 'center',
                    children = {
                        Expanded(title_bar),
                        window_controls,
                    },
                }),
            }),
            Expanded(SizedBox.shrink()),
            bottom,
        },
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
    self.auto_hide_timeout = options.auto_hide_timeout == nil and 3 or options.auto_hide_timeout
    self.auto_hide_enabled = options.auto_hide_enabled ~= false
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
            return app.extension
        end,
    })
    self.main_entry = OverlayEntry({
        key = 'default-app-main',
        builder = function(context)
            return AutoHide({
                controller = self.main_controller,
                timeout = app.auto_hide_timeout,
                enabled = app.auto_hide_enabled,
                child = app.main or Main({ title = app.title, scale = app.scale }),
            })
        end,
    })
    self.window_entry = OverlayEntry({
        key = 'default-app-window-layer',
        builder = function()
            return app.window_layer or WindowLayer()
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

function DefaultAppState:notify_activity()
    self.main_controller:activity()
end

function DefaultApp:create_state()
    return DefaultAppState()
end

M.WidgetsApp = WidgetsApp
M.Main = Main
M.WindowLayer = WindowLayer
M.DefaultApp = DefaultApp
M.DefaultAppState = DefaultAppState

return M
