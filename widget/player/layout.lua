-- Root-relative ModernX original/reduced player geometry and composition.

local std = require 'elxlibs.std'
local geometry = require 'foundation.geometry'
local text_style_mod = require 'text.text_style'
local ambient_mod = require 'widget.ambient'
local actions_mod = require 'widget.actions'
local basic_widgets = require 'widget.widgets.basic'
local layout_widgets = require 'widget.widgets.layout'
local decorated_box_mod = require 'widget.widgets.decorated_box'
local widget_mod = require 'widget.widget'
local theme_mod = require 'widget.player.theme'
local icon_map = require 'widget.player.icon_map'
local progress_mod = require 'widget.player.progress_bar'

local Rect = geometry.Rect
local Offset = geometry.Offset
local EdgeInsets = geometry.EdgeInsets
local TextStyle = text_style_mod.TextStyle
local DisplayScope = ambient_mod.DisplayScope
local HostActions = actions_mod.HostActions
local Container = layout_widgets.Container
local Positioned = layout_widgets.Positioned
local Stack = layout_widgets.Stack
local SizedBox = layout_widgets.SizedBox
local Row = layout_widgets.Row
local Text = basic_widgets.Text
local IconButton = basic_widgets.IconButton
local ButtonStyle = basic_widgets.ButtonStyle
local Decoration = decorated_box_mod.Decoration
local PlayerThemeData = theme_mod.PlayerThemeData
local Icon = icon_map.icon
local ProgressBar = progress_mod.ProgressBar
local StatelessWidget = widget_mod.StatelessWidget

local raise = std.raise
local max = math.max
local min = math.min
local huge = math.huge
local Color = require 'foundation.color'.Color
local ColorTransparent = Color.rgba255(0, 0, 0, 0)
local ColorBlack = Color.rgba255(0, 0, 0, 255)

local M = {}

local function finite(name, value)
    if type(value) ~= 'number' or value ~= value or value == huge or value == -huge then
        raise(std.ValueError('PlayerLayout.' .. name .. ' must be finite'))
    end
    return value
end

local function non_negative(name, value)
    value = finite(name, value)
    if value < 0 then
        raise(std.ValueError('PlayerLayout.' .. name .. ' must be non-negative'))
    end
    return value
end

local function rect(left, top, width, height)
    return Rect.from_ltwh(left, top, max(0, width), max(0, height))
end

-- Rect already owns the root-relative edges.  This helper deliberately keeps
-- geometry as Rect values so RecordCanvas tests and Positioned use the same
-- source rather than maintaining a second coordinate representation.
local function safe_rect(left, top, right, bottom)
    return Rect(left, top, max(left, right), max(top, bottom))
end

---@param layout_option PlayerLayoutOption
---@param viewport_width number
---@param viewport_height number
---@param options table
---@return table<string, any>
local function geometry_for(layout_option, viewport_width, viewport_height, options)
    viewport_width = non_negative('viewport_width', viewport_width)
    viewport_height = non_negative('viewport_height', viewport_height)
    if layout_option ~= 'original' and layout_option ~= 'reduced' then
        raise(std.ValueError('PlayerLayout.layout_option must be original or reduced'))
    end
    options = options or {}

    local controller_height = options.controller_height or 180
    local seek_height = options.progress_bar_height or 16
    local center_bottom = layout_option == 'original' and 100 or 75
    local seek_width = layout_option == 'original' and viewport_width - 50
        or viewport_width - 200
    local seek_left = (viewport_width - seek_width) / 2
    local jump_buttons = options.jump_buttons == true
    local chapter_skip_buttons = options.chapter_skip_buttons ~= false
    local track_nextprev_buttons = options.track_nextprev_buttons ~= false
    local outeroffset = (chapter_skip_buttons and 0 or 100)
        + (jump_buttons and 0 or 100)
    local center_y = viewport_height - 40
    local seek_y = viewport_height - center_bottom
    local time_y = viewport_height - 84

    local actual_controller_height = min(controller_height, viewport_height)
    local controller_top = max(0, viewport_height - actual_controller_height)
    local result = {
        layout_option = layout_option,
        viewport = rect(0, 0, viewport_width, viewport_height),
        controller = rect(0, controller_top, viewport_width, actual_controller_height),
        window_bar = rect(0, 0, viewport_width, options.window_bar_height or 60),
        window_controls = safe_rect(
            viewport_width - (options.window_control_box_width or 138),
            15,
            viewport_width,
            15 + (options.window_control_height or 30)),
        window_title = safe_rect(12, 15, viewport_width - 150, 45),
        seekbar_background = rect(
            seek_left, seek_y - 1, seek_width, options.seekbar_height or 2),
        seekbar = rect(seek_left, seek_y - seek_height / 2, seek_width, seek_height),
        persistent_progress = rect(
            0, viewport_height - (options.persistent_progress_height or 17),
            viewport_width, options.persistent_progress_height or 17),
        title = nil,
        description = nil,
        time_left = rect(25, time_y - 10, 90, 20),
        time_right = safe_rect(viewport_width - 115, time_y - 10, viewport_width - 25, time_y + 10),
        chapter = nil,
        separator = nil,
        volume_background = nil,
        volume = nil,
        center = {},
        side = {},
        right = {},
        visibility = {},
        outeroffset = outeroffset,
    }

    local title_y = viewport_height - (layout_option == 'original' and 117 or 97)
    local title_width = layout_option == 'original' and viewport_width - 50 or viewport_width - 170
    result.title = rect(25, title_y - 35, title_width, 35)
    if layout_option == 'original' then
        result.chapter = rect(
            77, time_y - 10, viewport_width - 200, 20)
        result.separator = rect(65, time_y - 10, 30, 20)
        result.description = rect(25, viewport_height - 136, viewport_width - 50, 19)
    else
        result.chapter = rect(25, viewport_height - 144, 120, 19)
        result.description = safe_rect(
            viewport_width - 145, viewport_height - 134, viewport_width - 25, viewport_height - 115)
    end

    if options.has_description == true and layout_option == 'original' then
        result.title = rect(25, title_y - 55, title_width, 35)
    end

    local function centered(x, y, item_width, item_height)
        return rect(x - item_width / 2, y - item_height / 2, item_width, item_height)
    end

    local offset = jump_buttons and 60 or 0
    if track_nextprev_buttons then
        result.center.playlist_prev = centered(
            viewport_width / 2 - (60 + (chapter_skip_buttons and 60 or 0)) - offset,
            center_y, 30, 24)
        result.center.playlist_next = centered(
            viewport_width / 2 + (60 + (chapter_skip_buttons and 60 or 0)) + offset,
            center_y, 30, 24)
    end
    if chapter_skip_buttons then
        result.center.chapter_prev = centered(viewport_width / 2 - 60 - offset, center_y, 30, 24)
        result.center.chapter_next = centered(viewport_width / 2 + 60 + offset, center_y, 30, 24)
    end
    if jump_buttons then
        result.center.jump_back = centered(viewport_width / 2 - 60, center_y, 30, 24)
        result.center.jump_forward = centered(viewport_width / 2 + 60, center_y, 30, 24)
    end
    result.center.play = centered(viewport_width / 2, center_y, 45, 45)

    result.side.audio = centered(37, center_y, 24, 24)
    result.side.subtitle = centered(82, center_y, 24, 24)
    result.side.volume = centered(127, center_y, 24, 24)
    result.volume_background = rect(155, center_y - 1, options.volume_width or 80, 2)
    result.volume = rect(155, center_y - 4, options.volume_width or 80, 8)

    local right_center = {
        fullscreen = viewport_width - 37,
        loop = viewport_width - 82,
        ontop = viewport_width - 127,
        info = viewport_width - 172,
        screenshot = viewport_width - 217,
        download = viewport_width - 262,
    }
    local right_shift = 0
    local function right_control(name, enabled, threshold)
        if enabled then
            result.right[name] = centered(right_center[name] + right_shift, center_y, 24, 24)
            result.visibility[name] = viewport_width >= threshold - outeroffset
            right_shift = right_shift - 45
        end
    end
    right_control('fullscreen', true, 250)
    right_control('loop', options.loop_button == true, 600)
    right_control('ontop', options.ontop_button ~= false, 700)
    right_control('info', options.info_button == true, 500)
    right_control('screenshot', options.screenshot_button == true, 300)
    right_control('download', options.download_button == true and options.is_url == true, 400)

    result.visibility.audio = viewport_width >= 500 - outeroffset
    result.visibility.subtitle = viewport_width >= 600 - outeroffset
    result.visibility.volume = viewport_width >= 700 - outeroffset
    result.visibility.volume_control = options.volume_control ~= false
    result.visibility.title = options.show_title ~= false
    result.visibility.chapter = options.show_chapter_title ~= false
    result.visibility.description = options.has_description == true and options.show_description ~= false
    result.visibility.persistent_progress = options.persistent_progress == true
    return result
end

M.geometry_for = geometry_for

local function snapshot_text(snapshot, names, fallback)
    if snapshot then
        for _, name in ipairs(names) do
            local value = snapshot:get(name)
            if (type(value) == 'string' or type(value) == 'number') and tostring(value) ~= '' then
                return tostring(value)
            end
        end
    end
    return fallback
end

local function snapshot_number(snapshot, name)
    local value = snapshot and snapshot:get(name) or nil
    if type(value) ~= 'number' or value ~= value or value == huge or value == -huge then
        return nil
    end
    return value
end

local function clamp_fraction(value)
    return max(0, min(1, value))
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
        return clamp_fraction((position + max(0, buffered_duration)) / duration)
    end
    return 0
end

local function text_style(theme, options)
    options = options or {}
    local values = {}
    for key, value in pairs(options) do
        values[key] = value
    end
    values.color = values.color or theme.title_color
    values.blur_radius = values.blur_radius == nil and 1 or values.blur_radius
    values.outline_width = values.outline_width == nil and 0.5 or values.outline_width
    values.outline_color = values.outline_color or ColorBlack
    return TextStyle(values)
end

local function panel(theme, color, border_color, blur_radius)
    return Container({
        decoration = Decoration({
            color = color,
            border_width = 1,
            border_color = border_color,
            blur_radius = blur_radius,
        }),
    })
end

local function control_style(theme)
    return ButtonStyle({
        background_color = ColorTransparent,
        hover_color = theme.hover_color,
        pressed_color = theme.pressed_color,
        disabled_color = ColorTransparent,
        foreground_color = theme.side_button_color,
        padding = EdgeInsets.zero(),
        radius = 0,
        hover_scale = theme.hover_scale,
    })
end

local function icon_control(
    theme, actions, name, action_name, icon_name, item_rect, icon_size, color, custom_callback, style)
    local callback = custom_callback
    if callback == nil and action_name then
        callback = function()
            actions[action_name](actions)
        end
    end
    local hitbox = Container({
        width = max(0, item_rect:width()),
        height = max(0, item_rect:height()),
        alignment = Offset(0.5, 0.5),
        child = Icon(icon_name, { size = icon_size, color = color }),
    })
    return IconButton({
        key = 'player-' .. name,
        icon = hitbox,
        enabled = action_name == nil or actions:has(action_name),
        on_click = callback,
        style = style or control_style(theme),
    })
end

local function positioned(item_rect, child)
    return Positioned({
        left = item_rect.left,
        top = item_rect.top,
        width = item_rect:width(),
        height = item_rect:height(),
        child = child,
    })
end

---@class _PlayerLayoutOptions
---@field theme PlayerThemeData
---@field actions HostActions
---@field snapshot PlayerSnapshot?
---@field title string
---@field title_bar Widget?
---@field window_controls Widget?
---@field bottom Widget?
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
---@field layout_option PlayerLayoutOption
---@field top_bar_visible boolean
---@field scale number
---@overload fun(options: _PlayerLayoutOptions): self
local PlayerLayout = std.class.new('PlayerLayout', { StatelessWidget })

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

---@param theme PlayerThemeData
---@param title string
---@return Widget
local function default_title_bar(theme, title)
    return Container({
        alignment = Offset(0, 0.5),
        child = Text(title, {
            style = TextStyle({
                font_size = 19,
                color = theme.title_color,
                blur_radius = 1,
                outline_width = 0.5,
                outline_color = ColorBlack,
                wrap = false,
            }),
        }),
    })
end

---@param theme PlayerThemeData
---@param actions HostActions
---@return Widget
local function default_window_controls(theme, actions)
    local function control(name, icon_name, action_name, hover_color)
        local item = Rect.from_ltwh(0, 0, theme.window_control_width, theme.window_control_height)
        local style = control_style(theme)
        if hover_color then
            style = style:copy_with({ hover_color = hover_color })
        end
        return icon_control(
            theme, actions, name, action_name, icon_name, item, theme.window_control_size,
            theme.window_control_color, nil, style)
    end
    return Row({
        main_axis_size = 'max',
        main_alignment = 'center',
        cross_alignment = 'center',
        spacing = 4,
        children = {
            control('minimize', 'minimize', 'minimize', Color.rgba255(83, 164, 252, 90)),
            control('maximize', 'maximize', 'toggle_maximized', Color.rgba255(83, 164, 252, 90)),
            control('close', 'close', 'close', Color.rgba255(232, 17, 35, 120)),
        },
    })
end

---@param theme PlayerThemeData
---@param actions HostActions
---@param snapshot PlayerSnapshot?
---@param title string
---@param layout_geometry table<string, any>
---@return Widget[]
local function default_controller(theme, actions, snapshot, title, layout_geometry)
    local children = {}
    local description = snapshot_text(snapshot, { 'description', 'media_description' }, '')
    local duration = snapshot_number(snapshot, 'duration')
    local is_eof = snapshot and snapshot:get('eof_reached') == true
    local is_paused = snapshot and snapshot:get('pause') == true
    local play_icon = is_eof and 'replay' or (is_paused and 'play' or 'pause')
    local progress = player_progress(snapshot)
    local buffered = buffered_progress(snapshot)

    children[#children + 1] = positioned(
        layout_geometry.controller,
        panel(theme, theme.controller_color, theme.controller_border_color,
            theme.controller_blur_radius))
    if layout_geometry.visibility.persistent_progress then
        children[#children + 1] = positioned(layout_geometry.persistent_progress, ProgressBar({
            progress = progress,
            buffered = buffered,
            height = theme.persistent_progress_height,
            handle_size = 0,
            track_color = ColorTransparent,
            buffered_color = theme.seekbar_buffer_color,
            progress_color = theme.seekbar_progress_color,
            handle_color = theme.seekbar_progress_color,
            enabled = false,
        }))
    end
    children[#children + 1] = positioned(
        layout_geometry.seekbar_background,
        Container({ color = theme.seekbar_track_color }))
    local seek_callback
    if duration ~= nil and duration > 0 and actions:has('seek_to') then
        seek_callback = function(fraction)
            actions:seek_to(duration * fraction)
        end
    end
    children[#children + 1] = positioned(layout_geometry.seekbar, ProgressBar({
        progress = progress,
        buffered = buffered,
        height = theme.progress_bar_height,
        track_color = ColorTransparent,
        buffered_color = theme.seekbar_buffer_color,
        progress_color = theme.seekbar_progress_color,
        handle_color = theme.seekbar_progress_color,
        on_seek = seek_callback,
        enabled = seek_callback ~= nil,
    }))

    local label_style = TextStyle({
        font_size = theme.time_font_size,
        color = theme.time_color,
        outline_width = 1,
        outline_color = ColorBlack,
        wrap = false,
    })
    if layout_geometry.visibility.title then
        local title_style = TextStyle({
            font_size = theme.title_font_size,
            color = theme.title_color,
            blur_radius = 1,
            outline_width = 0.5,
            outline_color = ColorBlack,
            wrap = false,
        })
        children[#children + 1] = positioned(
            layout_geometry.title,
            Container({ alignment = Offset(0, 0.5), child = Text(title, { style = title_style }) }))
    end
    if layout_geometry.visibility.description then
        local description_style = TextStyle({
            font_size = theme.description_font_size,
            color = theme.description_color,
            blur_radius = 1,
            outline_width = 0.5,
            outline_color = ColorBlack,
            wrap = false,
            align = layout_geometry.layout_option == 'reduced' and 'right' or 'left',
        })
        children[#children + 1] = positioned(
            layout_geometry.description,
            Container({ alignment = Offset(0, 0.5), child = Text(description, {
                style = description_style,
            }) }))
    end
    children[#children + 1] = positioned(layout_geometry.time_left, Container({
        alignment = Offset(0, 0.5),
        child = Text(format_time(snapshot_number(snapshot, 'time_pos')), { style = label_style }),
    }))
    children[#children + 1] = positioned(layout_geometry.time_right, Container({
        alignment = Offset(1, 0.5),
        child = Text(format_time(duration), { style = label_style }),
    }))
    if layout_geometry.visibility.chapter then
        local chapter = snapshot_text(snapshot, { 'chapter_title', 'chapter' }, '')
        if chapter ~= '' then
            local chapter_style = TextStyle({
                font_size = theme.time_font_size,
                color = theme.chapter_color,
                outline_width = 1,
                outline_color = ColorBlack,
                wrap = false,
            })
            if layout_geometry.separator then
                children[#children + 1] = positioned(layout_geometry.separator, Container({
                    alignment = Offset(0, 0.5),
                    child = Text('·', { style = chapter_style }),
                }))
            end
            children[#children + 1] = positioned(layout_geometry.chapter, Container({
                alignment = layout_geometry.layout_option == 'original'
                    and Offset(0, 0.5) or Offset(0, 0.5),
                child = Text(chapter, { style = chapter_style }),
            }))
        end
    end

    if layout_geometry.visibility.volume_control then
        children[#children + 1] = positioned(
            layout_geometry.volume_background,
            Container({ color = theme.volume_track_color }))
    end
    if layout_geometry.visibility.volume_control and actions:has('set_volume') then
        local volume = snapshot_number(snapshot, 'volume') or 0
        children[#children + 1] = positioned(layout_geometry.volume, ProgressBar({
            progress = clamp_fraction(volume / 100),
            buffered = 0,
            height = 8,
            handle_size = 0,
            track_color = ColorTransparent,
            progress_color = theme.volume_progress_color,
            buffered_color = ColorTransparent,
            handle_color = theme.volume_progress_color,
            on_seek = function(fraction)
                actions:set_volume(fraction * 100)
            end,
            enabled = true,
        }))
    end

    local function add_center(name, action_name, icon_name, icon_size, color, callback)
        local item_rect = layout_geometry.center[name]
        if item_rect then
            children[#children + 1] = positioned(item_rect, icon_control(
                theme, actions, name, action_name, icon_name, item_rect, icon_size, color, callback))
        end
    end
    if layout_geometry.center.playlist_prev then
        add_center('playlist_prev', 'playlist_prev', 'previous', theme.middle_button_size,
            theme.middle_button_color)
        add_center('playlist_next', 'playlist_next', 'next', theme.middle_button_size,
            theme.middle_button_color)
    end
    if layout_geometry.center.chapter_prev then
        add_center('chapter_prev', 'chapter_prev', 'rewind', theme.middle_button_size,
            theme.middle_button_color)
        add_center('chapter_next', 'chapter_next', 'forward', theme.middle_button_size,
            theme.middle_button_color)
    end
    if layout_geometry.center.jump_back then
        add_center('jump_back', 'seek', 'rewind', theme.middle_button_size,
            theme.middle_button_color, function()
                actions:seek(-10)
            end)
        add_center('jump_forward', 'seek', 'forward', theme.middle_button_size,
            theme.middle_button_color, function()
                actions:seek(10)
            end)
    end
    add_center('play', is_eof and 'replay' or 'play_pause', play_icon,
        theme.playpause_size, theme.playpause_color)

    local function add_side(name, action_name, icon_name)
        local item_rect = layout_geometry.side[name]
        if item_rect and layout_geometry.visibility[name] then
            children[#children + 1] = positioned(item_rect, icon_control(
                theme, actions, name, action_name, icon_name, item_rect,
                theme.side_button_size, theme.side_button_color))
        end
    end
    add_side('audio', 'cycle_audio', 'audio')
    add_side('subtitle', 'cycle_subtitle', 'subtitle')
    local volume_icon = snapshot and snapshot:get('mute') == true and 'volume_mute' or 'volume_up'
    add_side('volume', 'toggle_mute', volume_icon)

    local right_icons = {
        { name = 'fullscreen', action = 'toggle_fullscreen',
            icon = snapshot and snapshot:get('fullscreen') == true
                and 'fullscreen_exit' or 'fullscreen' },
        { name = 'loop', action = 'toggle_loop',
            icon = snapshot and snapshot:get('loop_file') == true and 'repeat_on' or 'repeat' },
        { name = 'ontop', action = 'toggle_ontop',
            icon = snapshot and snapshot:get('ontop') == true and 'pinned' or 'unpinned' },
        { name = 'info', action = 'show_message', icon = 'info' },
        { name = 'screenshot', action = 'screenshot', icon = 'screenshot' },
        { name = 'download', action = 'show_message', icon = 'download' },
    }
    for _, item in ipairs(right_icons) do
        local name = item.name
        local item_rect = layout_geometry.right[name]
        if item_rect and layout_geometry.visibility[name] then
            local action_name = item.action
            local action = action_name
            if name == 'info' or name == 'download' then
                action = nil
            end
            children[#children + 1] = positioned(item_rect, icon_control(
                theme, actions, name, action, item.icon, item_rect,
                theme.side_button_size, theme.side_button_color))
        end
    end
    return children
end

---@param context BuildContext
---@return Widget
function PlayerLayout:build(context)
    local display = DisplayScope.maybe_of(context)
    local viewport_width = display and display.snapshot.width or 0
    local viewport_height = display and display.snapshot.height or 0
    if viewport_width <= 0 then
        viewport_width = 300
    end
    if viewport_height <= 0 then
        viewport_height = 180
    end

    local snapshot = self.snapshot
    local description = snapshot_text(snapshot, { 'description', 'media_description' }, '')
    local is_url = snapshot and snapshot:get('is_url') == true
    local layout_geometry = geometry_for(self.layout_option, viewport_width, viewport_height, {
        controller_height = self.theme.controller_height,
        window_bar_height = self.theme.window_bar_height,
        window_control_box_width = self.theme.window_control_box_width,
        window_control_height = self.theme.window_control_height,
        seekbar_height = self.theme.seekbar_height,
        progress_bar_height = self.theme.progress_bar_height,
        persistent_progress_height = self.theme.persistent_progress_height,
        volume_width = self.theme.volume_width,
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

    local title_bar = self.title_bar
    if title_bar == nil and self.theme.window_title then
        title_bar = default_title_bar(self.theme, self.title)
    end
    local window_controls = self.window_controls
    if window_controls == nil and self.theme.window_controls then
        window_controls = default_window_controls(self.theme, self.actions)
    end

    local children = {}
    if self.top_bar_visible and (title_bar or window_controls) then
        children[#children + 1] = positioned(layout_geometry.window_bar, panel(
            self.theme, self.theme.window_color, self.theme.window_border_color,
            self.theme.window_blur_radius))
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
            self.theme, self.actions, snapshot, self.title, layout_geometry)
        for _, child in ipairs(controller) do
            children[#children + 1] = child
        end
    end

    return Stack({ children = children })
end

M.PlayerLayout = PlayerLayout

return M
