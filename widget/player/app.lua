-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Default player shell widgets.  The generic WidgetsApp ambient wrapper stays
-- in widget/app.lua; this module owns Main, AutoHide and WindowLayer composition.

local std = require 'elxlibs.std'
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

local EdgeInsets = geometry.EdgeInsets
local Offset = geometry.Offset
local Size = geometry.Size
local TextStyle = text_style_mod.TextStyle
local StatelessWidget = widget_mod.StatelessWidget
local StatefulWidget = widget_mod.StatefulWidget
local State = require('widget.state').State
local ThemeData = ambient_mod.ThemeData
local Theme = ambient_mod.Theme
local HostActions = actions_mod.HostActions
local OverlayEntry = overlay_mod.OverlayEntry
local Theatre = overlay_mod.Theatre
local AutoHide = visibility_mod.AutoHide
local AutoHideController = visibility_mod.AutoHideController
local Container = layout_widgets.Container
local Column = layout_widgets.Column
local Row = layout_widgets.Row
local Expanded = layout_widgets.Expanded
local SizedBox = layout_widgets.SizedBox
local LayoutScaleBox = layout_widgets.LayoutScaleBox
local Text = basic_widgets.Text
local TextButton = basic_widgets.TextButton
local ButtonStyle = basic_widgets.ButtonStyle
local ProgressBar = require('widget.player.progress_bar').ProgressBar

local raise = std.raise
local M = {}

local function child_or_empty(child)
    return child or SizedBox.shrink()
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

local function snapshot_number(snapshot, name)
    if not snapshot then
        return nil
    end
    local value = snapshot:get(name)
    if type(value) ~= 'number' or value ~= value
        or value == math.huge or value == -math.huge then
        return nil
    end
    return value
end

local function clamp_fraction(value)
    return math.max(0, math.min(1, value))
end

local function format_time(value)
    if value == nil or value < 0 then
        return '--:--'
    end
    local total = math.floor(value + 0.5)
    local seconds = total % 60
    local minutes = math.floor(total / 60) % 60
    local hours = math.floor(total / 3600)
    if hours > 0 then
        return string.format('%d:%02d:%02d', hours, minutes, seconds)
    end
    return string.format('%02d:%02d', minutes, seconds)
end

local function player_progress(snapshot)
    local percent = snapshot_number(snapshot, 'percent_pos')
    if percent ~= nil then
        return clamp_fraction(percent / 100)
    end
    local position = snapshot_number(snapshot, 'time_pos')
    local duration = snapshot_number(snapshot, 'duration')
    if position ~= nil and duration ~= nil and duration > 0 then
        return clamp_fraction(position / duration)
    end
    return 0
end

local function buffered_progress(snapshot)
    local explicit = snapshot_number(snapshot, 'buffered_percent')
    if explicit ~= nil then
        return clamp_fraction(explicit / 100)
    end
    local position = snapshot_number(snapshot, 'time_pos') or 0
    local duration = snapshot_number(snapshot, 'duration')
    local buffered_duration = snapshot_number(snapshot, 'buffered_duration')
    if duration ~= nil and duration > 0 and buffered_duration ~= nil then
        return clamp_fraction((position + math.max(0, buffered_duration)) / duration)
    end
    return 0
end

local function control_style(theme)
    return ButtonStyle({
        background_color = theme.surface_color,
        hover_color = theme.accent_color:with_alpha(0.42),
        pressed_color = theme.accent_color:with_alpha(0.62),
        foreground_color = theme.text_style.color,
        padding = EdgeInsets.symmetric(10, 4),
        hover_scale = 1.08,
    })
end

function Main:_default_title_bar(theme, snapshot)
    local title = snapshot_text(snapshot, { 'media_title', 'title', 'filename' }, self.title)
    return Container({
        padding = EdgeInsets.symmetric(10, 6),
        color = theme.surface_color,
        child = Text(title, {
            style = theme.text_style:copy_with({ bold = true, font_size = theme.text_style.font_size + 1 }),
        }),
    })
end

function Main:_default_window_controls(actions, theme)
    local font_size = math.max(11, theme.text_style.font_size - 1)
    local style = control_style(theme)
    return Row({
        spacing = 4,
        children = {
            TextButton({ label = '−', font_size = font_size, style = style, on_click = function()
                actions:minimize()
            end }),
            TextButton({ label = '□', font_size = font_size, style = style, on_click = function()
                actions:toggle_fullscreen()
            end }),
            TextButton({ label = '×', font_size = font_size, style = style, on_click = function()
                actions:close()
            end }),
        },
    })
end

function Main:_default_bottom(actions, theme, snapshot)
    local label_style = theme.text_style:copy_with({ font_size = math.max(11, theme.text_style.font_size - 2) })
    local title = snapshot_text(snapshot, { 'media_title', 'title', 'filename' }, self.title)
    local position = format_time(snapshot_number(snapshot, 'time_pos'))
    local duration = format_time(snapshot_number(snapshot, 'duration'))
    local info = snapshot and snapshot:get('pause') == true and 'paused' or 'playing'
    local filename = snapshot_text(snapshot, { 'filename' }, '')
    if filename ~= '' and filename ~= title then
        info = info .. ' · ' .. filename
    end
    local duration_value = snapshot_number(snapshot, 'duration')
    local progress = player_progress(snapshot)
    local buffered = buffered_progress(snapshot)
    local seek = function(fraction)
        if duration_value ~= nil and duration_value > 0 then
            actions:seek_to(duration_value * fraction)
        end
    end
    local style = control_style(theme)
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
            SizedBox({
                height = 14,
                child = ProgressBar({
                    progress = progress,
                    buffered = buffered,
                    track_color = theme.text_style.color:with_alpha(0.22),
                    buffered_color = theme.text_style.color:with_alpha(0.38),
                    progress_color = theme.accent_color,
                    handle_color = theme.accent_color,
                    on_seek = function(fraction)
                        seek(fraction)
                    end,
                }),
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
                        TextButton({
                            label = snapshot and snapshot:get('pause') == true and 'Play' or 'Pause',
                            style = style,
                            on_click = function() actions:play_pause() end,
                        }),
                        TextButton({ label = '−10', style = style, on_click = function()
                            actions:seek(-10)
                        end }),
                        TextButton({ label = '+10', style = style, on_click = function()
                            actions:seek(10)
                        end }),
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
    local title_bar = self.title_bar or self:_default_title_bar(theme, snapshot)
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
---@field auto_hide_bottom_hover boolean?
---@field auto_hide_hover_zone number?
---@field auto_hide_top_hover boolean?
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
---@field auto_hide_bottom_hover boolean
---@field auto_hide_hover_zone number
---@field auto_hide_top_hover boolean
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
    self.auto_hide_timeout = options.auto_hide_timeout == nil and 3 or options.auto_hide_timeout
    self.auto_hide_enabled = options.auto_hide_enabled ~= false
    self.auto_hide_bottom_hover = options.auto_hide_bottom_hover == true
    self.auto_hide_hover_zone = options.auto_hide_hover_zone == nil and 175
        or options.auto_hide_hover_zone
    self.auto_hide_top_hover = options.auto_hide_top_hover == true
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
                bottom_hover = app.auto_hide_bottom_hover,
                hover_zone = app.auto_hide_hover_zone,
                top_hover = app.auto_hide_top_hover,
                top_hover_zone = app.auto_hide_top_hover_zone,
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
