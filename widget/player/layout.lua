-- Player root layout: geometry selection and component assembly.

local std = require 'elxlibs.std'
local geometry = require 'foundation.geometry'
local ambient_mod = require 'widget.ambient'
local actions_mod = require 'widget.actions'
local layout_widgets = require 'widget.widgets.layout'
local widget_mod = require 'widget.widget'
local theme_mod = require 'widget.player.theme'
local metadata_mod = require 'widget.player.metadata'

local DisplayScope = ambient_mod.DisplayScope
local HostActions = actions_mod.HostActions
local Stack = layout_widgets.Stack
local SizedBox = layout_widgets.SizedBox
local PlayerThemeData = theme_mod.PlayerThemeData
local player_metadata = metadata_mod
local StatelessWidget = widget_mod.StatelessWidget

local raise = std.raise
local geometry_mod = require 'widget.player.geometry'
local description_mod = require 'widget.player.description'
local visuals_mod = require 'widget.player.visuals'
local controls_mod = require 'widget.player.controls'
local geometry_for = geometry_mod.geometry_for
local PlayerDescriptionLayer = description_mod.PlayerDescriptionLayer
local idle_view = visuals_mod.idle_view
local panel = visuals_mod.panel
local positioned = visuals_mod.positioned
local default_title_bar = visuals_mod.default_title_bar
local default_window_controls = visuals_mod.default_window_controls
local default_controller = controls_mod.default_controller

local M = {}

---@class _PlayerLayoutOptions
---@field theme PlayerThemeData
---@field actions HostActions
---@field snapshot PlayerSnapshot?
---@field title string
---@field title_bar Widget?
---@field window_controls Widget?
---@field bottom Widget?
---@field extra_right_control Widget?
---@field layout_option PlayerLayoutOption
---@field top_bar_visible boolean
---@field scale number
---@field key any?

---@class PlayerLayout : StatelessWidget
---@field theme PlayerThemeData
---@field actions HostActions
---@field snapshot PlayerSnapshot?
---@field title string
---@field title_bar Widget?
---@field window_controls Widget?
---@field bottom Widget?
---@field extra_right_control Widget?
---@field layout_option PlayerLayoutOption
---@field top_bar_visible boolean
---@field scale number
---@overload fun(options: _PlayerLayoutOptions): self
local PlayerLayout = std.class.new('PlayerLayout', StatelessWidget)

function PlayerLayout:__init(options)
    if type(options) ~= 'table' then
        raise(std.TypeError('PlayerLayout expects an options table'))
    end
    self.key = options.key
    self.theme = options.theme or PlayerThemeData()
    self.actions = options.actions or HostActions()
    self.snapshot = options.snapshot
    self.title = options.title or 'elxosc'
    self.title_bar = options.title_bar
    self.window_controls = options.window_controls
    self.bottom = options.bottom
    self.extra_right_control = options.extra_right_control
    self.layout_option = options.layout_option or self.theme.layout_option
    self.top_bar_visible = options.top_bar_visible ~= false
    self.scale = options.scale or 1
    if not std.isinstance(self.theme, PlayerThemeData) then
        raise(std.TypeError('PlayerLayout.theme must be PlayerThemeData'))
    end
    if not std.isinstance(self.actions, HostActions) then
        raise(std.TypeError('PlayerLayout.actions must be HostActions'))
    end
end
---@param context BuildContext
---@return Widget
function PlayerLayout:build(context)
    local display = DisplayScope.maybe_of(context)
    local display_width = display and display.snapshot.width or 0
    local display_height = display and display.snapshot.height or 0
    local scale = self.scale > 0 and self.scale or 1
    local viewport_width = display_width / scale
    local viewport_height = display_height / scale
    if viewport_width <= 0 then
        viewport_width = 300
    end
    if viewport_height <= 0 then
        viewport_height = 180
    end

    local snapshot = self.snapshot
    local description = player_metadata.description(snapshot)
    local is_url = player_metadata.is_url(snapshot)
    if snapshot and snapshot:get('idle_active') == true then
        return idle_view(self.theme, self.title)
    end
    local layout_geometry = geometry_for(self.layout_option, viewport_width, viewport_height, {
        controller_height = self.theme.controller_height,
        window_bar_height = self.theme.window_bar_height,
        window_control_box_width = self.theme.window_control_box_width,
        window_control_height = self.theme.window_control_height,
        seekbar_height = self.theme.seekbar_height,
        progress_bar_height = self.theme.progress_bar_height,
        persistent_progress_height = self.theme.persistent_progress_height,
        volume_width = self.theme.volume_width,
        extra_right_control = self.extra_right_control ~= nil,
        jump_buttons = self.theme.jump_buttons and not self.theme.compact_mode,
        chapter_skip_buttons = self.theme.chapter_skip_buttons,
        track_nextprev_buttons = self.theme.track_nextprev_buttons,
        loop_button = self.theme.loop_button,
        ontop_button = self.theme.ontop_button,
        info_button = self.theme.info_button,
        screenshot_button = self.theme.screenshot_button,
        download_button = self.theme.download_button,
        volume_control = self.theme.volume_control,
        show_title = self.theme.show_title,
        show_description = self.theme.show_description,
        show_chapter_title = self.theme.show_chapter_title,
        persistent_progress = self.theme.persistent_progress,
        has_description = description ~= '',
        is_url = is_url,
    })
    layout_geometry.scale = scale

    local title_bar = self.title_bar
    if title_bar == nil and self.theme.window_title then
        title_bar = default_title_bar(self.theme, self.title)
    end
    local window_controls = self.window_controls
    if window_controls == nil and self.theme.window_controls then
        window_controls = default_window_controls(self.theme, self.actions, snapshot)
    end

    local children = {}
    if self.top_bar_visible and (title_bar or window_controls) then
        children[#children + 1] = positioned(layout_geometry.window_bar, panel(
            self.theme, self.theme.window_color, self.theme.window_border_color,
            self.theme.window_blur_radius, true))
        if title_bar then
            children[#children + 1] = positioned(layout_geometry.window_title, title_bar)
        end
        if window_controls then
            children[#children + 1] = positioned(layout_geometry.window_controls, window_controls)
        end
    end

    if self.bottom then
        children[#children + 1] = positioned(layout_geometry.controller, self.bottom)
    else
        local controller = default_controller(
            self.theme, self.actions, snapshot, self.title, layout_geometry, self.extra_right_control)
        for _, child in ipairs(controller) do
            children[#children + 1] = child
        end
    end

    if layout_geometry.visibility.description and description ~= '' then
        children[#children + 1] = SizedBox({
            width = viewport_width,
            height = viewport_height,
            child = PlayerDescriptionLayer({
                theme = self.theme,
                text = description,
                preview = player_metadata.preview(description),
                bounds = layout_geometry.description,
                viewport_width = viewport_width,
                viewport_height = viewport_height,
                actions = self.actions,
                links = player_metadata.links(description),
                stats = player_metadata.stats(snapshot),
            }),
        })
    end

    return Stack({ children = children })
end

M.geometry_for = geometry_for
M.PlayerLayout = PlayerLayout
M.PlayerDescriptionLayer = PlayerDescriptionLayer

return M
