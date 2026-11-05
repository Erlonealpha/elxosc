-- Default playback, timeline, track, volume and optional controls.

local geometry = require 'foundation.geometry'
local text_style_mod = require 'text.text_style'
local basic_widgets = require 'widget.widgets.basic'
local layout_widgets = require 'widget.widgets.layout'
local progress_mod = require 'widget.player.progress_bar'
local tooltip_mod = require 'widget.player.tooltip'
local metadata_mod = require 'widget.player.metadata'
local paint_mod = require 'painting.paint'

local Offset = geometry.Offset
local Rect = geometry.Rect
local Paint = paint_mod.Paint
local TextStyle = text_style_mod.TextStyle
local Container = layout_widgets.Container
local SizedBox = layout_widgets.SizedBox
local Text = basic_widgets.Text
local ProgressBar = progress_mod.ProgressBar
local PlayerTooltip = tooltip_mod.PlayerTooltip
local player_metadata = metadata_mod

local max = math.max
local min = math.min
local color_mod = require 'foundation.color'
local Color = color_mod.Color
local ColorTransparent = Color.rgba255(0, 0, 0, 0)
local ColorBlack = Color.rgba255(0, 0, 0, 255)
local data_mod = require 'widget.player.data'
local visuals_mod = require 'widget.player.visuals'
local text_controls_mod = require 'widget.player.text_controls'
local PlayerTimeDisplay = text_controls_mod.PlayerTimeDisplay
local PlayerHoverText = text_controls_mod.PlayerHoverText
local snapshot_number = data_mod.snapshot_number
local capability_available = data_mod.capability_available
local capability_info = data_mod.capability_info
local chapter_entries = data_mod.chapter_entries
local current_chapter_title = data_mod.current_chapter_title
local clamp_fraction = data_mod.clamp_fraction
local format_time = data_mod.format_time
local chapter_title_at_fraction = data_mod.chapter_title_at_fraction
local player_progress = data_mod.player_progress
local chapter_markers = data_mod.chapter_markers
local seek_ranges = data_mod.seek_ranges
local sponsor_ranges = data_mod.sponsor_ranges
local track_ids = data_mod.track_ids
local track_tooltip = data_mod.track_tooltip
local track_list_message = data_mod.track_list_message
local next_track = data_mod.next_track
local nearest_chapter = data_mod.nearest_chapter
local text_style = visuals_mod.text_style
local panel = visuals_mod.panel
local icon_control = visuals_mod.icon_control
local positioned = visuals_mod.positioned

local M = {}

---@param theme PlayerThemeData
---@param actions HostActions
---@param snapshot PlayerSnapshot?
---@param title string
---@param layout_geometry table<string, any>
---@param extra_right_control Widget?
---@return Widget[]
local function default_controller(theme, actions, snapshot, title, layout_geometry, extra_right_control)
    local children = {}
    local function bounded_interaction(interaction, item_rect)
        if interaction == nil then
            return nil
        end
        local result = {}
        for key, value in pairs(interaction) do
            result[key] = value
        end
        result.tooltip_bounds_width = layout_geometry.viewport:width()
        result.tooltip_bounds_height = layout_geometry.viewport:height()
        result.tooltip_anchor_left = item_rect.left
        result.tooltip_anchor_top = item_rect.top
        return result
    end
    local function show_message(message)
        if actions:has('show_message') then
            actions:show_message(message)
        end
    end
    local function jump_icon(direction, amount)
        if not theme.jump_icon_number then
            return direction
        end
        local names = direction == 'rewind' and {
            [5] = 'rewind_5', [10] = 'rewind_10', [30] = 'rewind_30',
        } or {
            [5] = 'forward_5', [10] = 'forward_10', [30] = 'forward_30',
        }
        return names[amount] or direction
    end
    local function jump_seek(seconds)
        if actions:has('seek') then
            actions:seek(seconds, theme.jump_mode)
        end
    end
    local is_url = player_metadata.is_url(snapshot)
    local duration = snapshot_number(snapshot, 'duration')
    local is_eof = snapshot and snapshot:get('eof_reached') == true
    local is_paused = snapshot and snapshot:get('pause') == true
    local play_icon = is_eof and 'replay' or (is_paused and 'play' or 'pause')
    local progress = player_progress(snapshot)
    local markers = theme.show_chapter_markers and chapter_markers(snapshot, duration) or {}
    local cache_ranges = seek_ranges(snapshot, duration)
    local ranges = {}
    for _, range in ipairs(cache_ranges) do
        ranges[#ranges + 1] = range
    end
    for _, range in ipairs(sponsor_ranges(snapshot, duration)) do
        ranges[#ranges + 1] = range
    end
    local thumbfast_enabled = capability_available(snapshot, 'thumbfast')
        and actions:has('thumbfast_request')

    local function thumbfast_size()
        local info = snapshot and snapshot:capability('thumbfast') or nil
        local detail = info and info.detail or nil
        if type(detail) ~= 'string' then
            return nil, nil
        end
        local width, height = detail:match('^(%d+)x(%d+)$')
        return tonumber(width), tonumber(height)
    end

    local function thumbfast_rect(point)
        local width, height = thumbfast_size()
        if width == nil or height == nil or width <= 0 or height <= 0 then
            return nil
        end
        local player_scale = layout_geometry.scale or 1
        local width_logical = width / player_scale
        local margin = 18 / player_scale
        local cursor_x = layout_geometry.seekbar.left + point.x
        local left = max(margin,
            min(layout_geometry.viewport:width() - margin - width_logical,
                cursor_x - width_logical / 2))
        local top = max(0, layout_geometry.seekbar.top - theme.time_font_size
            - (theme.thumbnail_border + 2 + height) / player_scale)
        -- The external image uses integer host coordinates. Share that exact
        -- rectangle with the in-tree frame and centered time label.
        return Rect.from_ltwh(
            math.floor(left * player_scale + 0.5) / player_scale,
            math.floor(top * player_scale + 0.5) / player_scale,
            width_logical, height / player_scale)
    end

    local function thumbfast_center(point)
        local rect = thumbfast_rect(point)
        return rect and (rect.left + rect:width() / 2 - layout_geometry.seekbar.left) or point.x
    end

    children[#children + 1] = positioned(
        layout_geometry.controller,
        panel(theme, theme.controller_color, theme.controller_border_color,
            theme.controller_blur_radius, false))
    if layout_geometry.visibility.persistent_progress then
        children[#children + 1] = positioned(layout_geometry.persistent_progress, ProgressBar({
            progress = progress,
            buffered = 0,
            height = theme.persistent_progress_height,
            handle_size = 0,
            track_color = ColorTransparent,
            buffered_color = theme.seekbar_buffer_color,
            progress_color = theme.seekbar_progress_color,
            handle_color = theme.seekbar_progress_color,
            ranges = theme.persistent_buffer and cache_ranges or {},
            range_expand = 7,
            enabled = false,
        }))
    end
    if not (theme.show_chapter_markers and theme.chapter_marker_style == 'gap') then
        children[#children + 1] = positioned(
            layout_geometry.seekbar_background,
            Container({ color = theme.seekbar_track_color }))
    end
    local seek_callback
    local seek_state = {
        was_playing = false,
        mode = 'keyframe',
    }
    if duration ~= nil and duration > 0 and actions:has('seek_to') then
        seek_callback = function(fraction, phase, mode)
            if phase == 'start' then
                seek_state.was_playing = snapshot ~= nil and snapshot:get('pause') ~= true
                seek_state.mode = mode or 'keyframe'
                if seek_state.was_playing and theme.mouse_seek_pause and actions:has('set_pause') then
                    actions:set_pause(true)
                end
                actions:seek_to(duration * fraction, seek_state.mode)
            elseif phase == 'update' then
                actions:seek_to(duration * fraction, seek_state.mode)
            elseif phase == 'end' then
                actions:seek_to(duration * fraction, seek_state.mode)
                if seek_state.was_playing and theme.mouse_seek_pause and actions:has('set_pause') then
                    actions:set_pause(false)
                end
                seek_state.was_playing = false
            elseif phase == 'cancel' then
                if seek_state.was_playing and theme.mouse_seek_pause and actions:has('set_pause') then
                    actions:set_pause(false)
                end
                seek_state.was_playing = false
            end
        end
    end
    local chapter_seek_callback
    if actions:has('set_chapter') and duration ~= nil and duration > 0 then
        chapter_seek_callback = function(fraction)
            local chapter = nearest_chapter(snapshot, fraction, duration)
            if chapter ~= nil then
                actions:set_chapter(chapter)
            end
        end
    end
    local seekbar = ProgressBar({
        progress = progress,
        buffered = 0,
        height = theme.progress_bar_height,
        track_color = theme.show_chapter_markers and theme.chapter_marker_style == 'gap'
            and theme.seekbar_track_color or ColorTransparent,
        buffered_color = theme.seekbar_buffer_color,
        progress_color = theme.seekbar_progress_color,
        handle_color = theme.seekbar_progress_color,
        hover_track_color = nil,
        hover_buffered_color = nil,
        hover_progress_color = nil,
        hover_handle_color = nil,
        hover_handle_size = 0.8,
        range_expand = 7,
        hover_expand = theme.seekbar_hit_expand,
        seek_mode = theme.seekbar_keyframes and 'keyframe' or 'exact',
        markers = markers,
        ranges = ranges,
        marker_color = theme.chapter_marker_color,
        current_marker_color = theme.chapter_marker_current_color,
        range_color = theme.seek_range_color,
        marker_style = theme.chapter_marker_style,
        on_seek = seek_callback,
        on_context_seek = chapter_seek_callback,
        enabled = seek_callback ~= nil,
    })
    children[#children + 1] = positioned(layout_geometry.seekbar, seekbar)
    children[#children + 1] = positioned(layout_geometry.seekbar, PlayerTooltip({
        child = SizedBox({
            width = layout_geometry.seekbar:width(),
            height = layout_geometry.seekbar:height(),
        }),
        enabled = duration ~= nil and duration > 0,
        follow_pointer = true,
        bounds_width = layout_geometry.viewport:width(),
        bounds_height = layout_geometry.viewport:height(),
        anchor_left = layout_geometry.seekbar.left,
        anchor_top = layout_geometry.seekbar.top,
        anchor_width = layout_geometry.seekbar:width(),
        anchor_height = layout_geometry.seekbar:height(),
        expand = theme.seekbar_hit_expand,
        offset_x = 0,
        gap = 0,
        position_for_point = thumbfast_enabled and thumbfast_center or nil,
        style = TextStyle({
            font_size = theme.time_font_size,
            color = theme.title_color,
            blur_radius = 1,
            outline_width = 0.5,
            outline_color = ColorBlack,
            wrap = false,
        }),
        text_for_point = function(point)
            if duration == nil or duration <= 0 then
                return nil
            end
            local fraction = clamp_fraction(point.x / layout_geometry.seekbar:width())
            local value = duration * fraction
            local text = format_time(value, theme.time_ms, theme.time_format == 'fixed')
            if not thumbfast_enabled and theme.chapter_hover_subtitle then
                local chapter = chapter_title_at_fraction(snapshot, fraction, duration)
                if chapter then
                    text = text .. ' · ' .. chapter
                end
            end
            return text
        end,
        on_hover_point = thumbfast_enabled and function(point)
            local fraction = clamp_fraction(point.x / layout_geometry.seekbar:width())
            local rect = thumbfast_rect(point)
            if rect == nil then
                return
            end
            local player_scale = layout_geometry.scale or 1
            actions:thumbfast_request(
                duration * fraction,
                math.floor(rect.left * player_scale + 0.5),
                math.floor(rect.top * player_scale + 0.5))
        end or nil,
        paint_for_point = thumbfast_enabled and function(canvas, offset, point)
            local rect = thumbfast_rect(point)
            if rect == nil or theme.thumbnail_border <= 0 then
                return
            end
            local player_scale = layout_geometry.scale or 1
            local border = theme.thumbnail_border / player_scale
            local outline = 1 / player_scale
            local radius = min(theme.thumbnail_border_radius, theme.thumbnail_border) / player_scale
            local origin = (offset - layout_geometry.seekbar:top_left()) --[[@as Offset]]
            local image = rect:shift(origin)
            canvas:draw_rrect(image:inflate(border + outline), radius + outline,
                Paint(theme.thumbnail_border_outline))
            canvas:draw_rrect(image:inflate(border), radius, Paint(theme.thumbnail_border_color))
        end or nil,
        on_hover_leave = thumbfast_enabled and function()
            if actions:has('thumbfast_clear') then
                actions:thumbfast_clear()
            end
        end or nil,
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
        local title_child = PlayerHoverText({
            text = title,
            style = title_style,
            alignment = Offset(0, 0.5),
            hover_color = theme.hover_color,
            hover_shadow_color = theme.hover_glow_color,
            hover_shadow_radius = theme.button_glow_amount,
            on_tap = function()
                if actions:has('show_stats') then
                    actions:show_stats()
                elseif actions:has('show_message') then
                    actions:show_message('Player information unavailable')
                end
            end,
        })
        children[#children + 1] = positioned(
            layout_geometry.title,
            Container({ alignment = Offset(0, 0.5), child = title_child }))
    end
    children[#children + 1] = positioned(layout_geometry.time_left, Container({
        child = PlayerTimeDisplay({
            value = snapshot_number(snapshot, 'time_pos'),
            duration = duration,
            show_milliseconds = theme.time_ms,
            unicode_minus = theme.unicode_minus,
            fixed = theme.time_format == 'fixed',
            toggle_mode = 'milliseconds',
            style = label_style,
            hover_color = theme.hover_color,
            hover_shadow_color = theme.hover_glow_color,
            hover_shadow_radius = theme.button_glow_amount,
            alignment = Offset(0, 0.5),
        }),
    }))
    children[#children + 1] = positioned(layout_geometry.time_right, Container({
        child = PlayerTimeDisplay({
            value = snapshot_number(snapshot, 'time_pos'),
            duration = duration,
            show_remaining = not theme.time_total,
            unicode_minus = theme.unicode_minus,
            fixed = theme.time_format == 'fixed',
            toggle_mode = 'remaining',
            suffix = player_metadata.is_live(snapshot) and ' • LIVE' or '',
            style = label_style,
            hover_color = theme.hover_color,
            hover_shadow_color = theme.hover_glow_color,
            hover_shadow_radius = theme.button_glow_amount,
            alignment = Offset(1, 0.5),
        }),
    }))
    if layout_geometry.visibility.chapter then
        local chapter = current_chapter_title(snapshot)
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
                child = PlayerHoverText({
                    text = chapter,
                    style = chapter_style,
                    hover_color = theme.hover_color,
                    hover_shadow_color = theme.hover_glow_color,
                    hover_shadow_radius = theme.button_glow_amount,
                    on_tap = function()
                        if actions:has('show_message') then
                            actions:show_message('Chapter list')
                        end
                    end,
                }),
            }))
        end
    end

    if layout_geometry.visibility.volume_control and layout_geometry.visibility.volume_slider then
        children[#children + 1] = positioned(
            layout_geometry.volume_background,
            Container({ color = theme.volume_track_color }))
    end
    if layout_geometry.visibility.volume_control and layout_geometry.visibility.volume_slider
        and actions:has('set_volume') then
        local volume = snapshot_number(snapshot, 'volume') or 0
        local volume_max = snapshot_number(snapshot, 'volume_max') or 100
        volume_max = volume_max > 0 and volume_max or 100
        local function volume_to_fraction(value)
            if theme.volume_control_type == 'logarithmic' then
                return math.sqrt(clamp_fraction(value / volume_max))
            end
            return clamp_fraction(value / volume_max)
        end
        local function fraction_to_volume(fraction)
            if theme.volume_control_type == 'logarithmic' then
                return clamp_fraction(fraction) * clamp_fraction(fraction) * volume_max
            end
            return clamp_fraction(fraction) * volume_max
        end
        children[#children + 1] = positioned(layout_geometry.volume, ProgressBar({
            progress = volume_to_fraction(volume),
            buffered = 0,
            height = 8,
            handle_size = 0.8,
            hover_handle_size = 0.8,
            hover_expand = theme.volume_hit_expand,
            track_color = ColorTransparent,
            progress_color = theme.volume_progress_color,
            buffered_color = ColorTransparent,
            handle_color = theme.volume_progress_color,
            hover_track_color = nil,
            hover_progress_color = nil,
            hover_handle_color = nil,
            on_seek = function(fraction, phase)
                if phase == 'start' or phase == 'update' or phase == 'end' then
                    actions:set_volume(fraction_to_volume(fraction))
                end
            end,
            on_wheel = function(delta)
                local next_volume = max(0, min(volume_max, volume + (delta > 0 and 5 or -5)))
                actions:set_volume(next_volume)
            end,
            enabled = true,
        }))
        children[#children + 1] = positioned(layout_geometry.volume, PlayerTooltip({
            child = SizedBox({
                width = layout_geometry.volume:width(),
                height = layout_geometry.volume:height(),
            }),
            enabled = true,
            follow_pointer = true,
            bounds_width = layout_geometry.viewport:width(),
            bounds_height = layout_geometry.viewport:height(),
            anchor_left = layout_geometry.volume.left,
            anchor_top = layout_geometry.volume.top,
            anchor_width = layout_geometry.volume:width(),
            anchor_height = layout_geometry.volume:height(),
            text_for_point = function(point)
                return string.format('%d%%', math.floor(
                    fraction_to_volume(point.x / layout_geometry.volume:width()) + 0.5))
            end,
            style = TextStyle({
                font_size = theme.time_font_size,
                color = theme.title_color,
                blur_radius = 1,
                outline_width = 0.5,
                outline_color = ColorBlack,
                wrap = false,
            }),
        }))
    end

    local function add_center(name, action_name, icon_name, icon_size, color, callback, interaction)
        local item_rect = layout_geometry.center[name]
        if item_rect then
            children[#children + 1] = positioned(item_rect, icon_control(
                theme, actions, name, action_name, icon_name, item_rect, icon_size, color,
                callback, nil, bounded_interaction(interaction, item_rect)))
        end
    end
    if layout_geometry.center.playlist_prev then
        local playlist_count = snapshot_number(snapshot, 'playlist_count') or 0
        local playlist_pos = snapshot_number(snapshot, 'playlist_pos') or 0
        add_center('playlist_prev', 'playlist_prev', 'previous', theme.middle_button_size,
            theme.middle_button_color, nil, {
                enabled = actions:has('playlist_prev') and playlist_pos > 0,
                on_right_click = actions:has('playlist_shuffle') and function()
                    actions:playlist_shuffle()
                    show_message('Playlist shuffled')
                end or nil,
                on_shift_click = function(button)
                    if button == 'left' and actions:has('select_playlist') then
                        actions:select_playlist()
                    elseif button == 'left' then
                        show_message('Playlist selector unavailable')
                    elseif button == 'right' and actions:has('playlist_first') then
                        actions:playlist_first()
                    elseif button == 'right' then
                        show_message('Playlist first-item action unavailable')
                    end
                end,
            })
        add_center('playlist_next', 'playlist_next', 'next', theme.middle_button_size,
            theme.middle_button_color, nil, {
                enabled = actions:has('playlist_next') and playlist_pos < playlist_count - 1,
                on_right_click = actions:has('playlist_shuffle') and function()
                    actions:playlist_shuffle()
                    show_message('Playlist shuffled')
                end or nil,
                on_shift_click = function(button)
                    if button == 'left' and actions:has('select_playlist') then
                        actions:select_playlist()
                    elseif button == 'left' then
                        show_message('Playlist selector unavailable')
                    elseif button == 'right' and actions:has('playlist_last') then
                        actions:playlist_last()
                    elseif button == 'right' then
                        show_message('Playlist last-item action unavailable')
                    end
                end,
            })
    end
    if layout_geometry.center.chapter_prev then
        local chapters = chapter_entries(snapshot)
        local has_chapters = #chapters > 0
        local function chapter_callback(delta)
            if theme.compact_mode and actions:has('seek') then
                jump_seek(delta * theme.jump_amount)
            elseif delta < 0 and actions:has('chapter_prev') then
                actions:chapter_prev()
            elseif delta > 0 and actions:has('chapter_next') then
                actions:chapter_next()
            else
                show_message('Chapter navigation unavailable')
            end
        end
        add_center('chapter_prev', nil, jump_icon('rewind', theme.jump_amount), theme.middle_button_size,
            theme.middle_button_color, function()
                chapter_callback(-1)
            end, {
                enabled = has_chapters or theme.compact_mode,
                on_right_click = function()
                    jump_seek(-theme.jump_more_amount)
                end,
                on_shift_click = function(button)
                    if button == 'left' and actions:has('select_chapter') then
                        actions:select_chapter()
                    elseif button == 'left' then
                        show_message('Chapter selector unavailable')
                    elseif button == 'right' and actions:has('chapter_next') then
                        actions:chapter_next()
                    elseif button == 'right' then
                        show_message('Chapter navigation unavailable')
                    end
                end,
                soft_repeat = theme.chapter_softrepeat,
            })
        add_center('chapter_next', nil, jump_icon('forward', theme.jump_amount), theme.middle_button_size,
            theme.middle_button_color, function()
                chapter_callback(1)
            end, {
                enabled = has_chapters or theme.compact_mode,
                on_right_click = function()
                    jump_seek(theme.jump_more_amount)
                end,
                on_shift_click = function(button)
                    if button == 'left' and actions:has('select_chapter') then
                        actions:select_chapter()
                    elseif button == 'left' then
                        show_message('Chapter selector unavailable')
                    elseif button == 'right' and actions:has('chapter_next') then
                        actions:chapter_next()
                    elseif button == 'right' then
                        show_message('Chapter navigation unavailable')
                    end
                end,
                soft_repeat = theme.chapter_softrepeat,
            })
    end
    if layout_geometry.center.jump_back then
        local jump_back_icon = jump_icon('rewind', theme.jump_amount)
        local jump_forward_icon = jump_icon('forward', theme.jump_amount)
        add_center('jump_back', nil, jump_back_icon, theme.middle_button_size,
            theme.middle_button_color, function()
                jump_seek(-theme.jump_amount)
            end, {
                enabled = actions:has('seek'),
                on_right_click = function()
                    jump_seek(-theme.jump_more_amount)
                end,
                on_shift_click = function()
                    if actions:has('frame_back_step') then
                        actions:frame_back_step()
                    end
                end,
                soft_repeat = theme.jump_softrepeat,
            })
        add_center('jump_forward', nil, jump_forward_icon, theme.middle_button_size,
            theme.middle_button_color, function()
                jump_seek(theme.jump_amount)
            end, {
                enabled = actions:has('seek'),
                on_right_click = function()
                    jump_seek(theme.jump_more_amount)
                end,
                on_shift_click = function()
                    if actions:has('frame_step') then
                        actions:frame_step()
                    end
                end,
                soft_repeat = theme.jump_softrepeat,
            })
    end
    add_center('play', is_eof and 'replay' or 'play_pause', play_icon,
        theme.playpause_size, theme.playpause_color, nil, {
            on_right_click = actions:has('playlist_shuffle') and function()
                actions:playlist_shuffle()
                show_message('Playlist shuffled')
            end or nil,
            on_shift_click = theme.loop_in_pause and is_paused and function()
                if actions:has('toggle_loop') then
                    actions:toggle_loop()
                end
            end or nil,
        })

    local function cycle_track(kind, delta)
        if kind == 'audio' and actions:has('clear_audio_filter') then
            actions:clear_audio_filter()
        end
        if kind == 'sub' and actions:has('clear_secondary_subtitle') then
            actions:clear_secondary_subtitle()
        end
        local next_id = next_track(snapshot, kind, delta)
        if next_id ~= nil and actions:has('set_track') then
            actions:set_track(kind, next_id)
            if actions:has('show_message') then
                actions:show_message(track_list_message(snapshot, kind))
            end
            return
        end
        if kind == 'audio' and delta > 0 and actions:has('cycle_audio') then
            actions:cycle_audio()
        elseif kind == 'audio' and delta < 0 and actions:has('cycle_audio_reverse') then
            actions:cycle_audio_reverse()
        elseif kind == 'sub' and delta > 0 and actions:has('cycle_subtitle') then
            actions:cycle_subtitle()
        elseif kind == 'sub' and delta < 0 and actions:has('cycle_subtitle_reverse') then
            actions:cycle_subtitle_reverse()
        end
        if actions:has('show_message') then
            actions:show_message(track_list_message(snapshot, kind))
        end
    end
    local function has_track_data(kind)
        if snapshot == nil or snapshot:get('track_list') == nil then
            return true
        end
        return #track_ids(snapshot, kind) > 0
    end
    local function add_side(name, action_name, icon_name, interaction)
        local item_rect = layout_geometry.side[name]
        if item_rect and layout_geometry.visibility[name] then
            children[#children + 1] = positioned(item_rect, icon_control(
                theme, actions, name, action_name, icon_name, item_rect,
                theme.side_button_size, theme.side_button_color,
                interaction and interaction.on_click or nil, nil,
                bounded_interaction(interaction, item_rect)))
        end
    end
    add_side('audio', nil, 'audio', {
        enabled = has_track_data('audio') and (actions:has('set_track') or actions:has('cycle_audio')),
        on_click = function()
            cycle_track('audio', 1)
        end,
        on_right_click = function()
            cycle_track('audio', -1)
        end,
        on_wheel = function(delta)
            cycle_track('audio', delta > 0 and 1 or -1)
        end,
        on_shift_click = function(button)
            if button == 'left' and actions:has('select_audio_track') then
                actions:select_audio_track()
            elseif button == 'left' then
                show_message('Audio selector unavailable')
            elseif button == 'right' and actions:has('load_audio_track') then
                actions:load_audio_track()
            elseif button == 'right' then
                show_message('External audio-track loader unavailable')
            end
        end,
        tooltip = track_tooltip(snapshot, 'audio'),
        disabled_tooltip = 'No audio available',
    })
    add_side('subtitle', nil, 'subtitle', {
        enabled = has_track_data('sub') and (actions:has('set_track') or actions:has('cycle_subtitle')),
        on_click = function()
            cycle_track('sub', 1)
        end,
        on_right_click = function()
            cycle_track('sub', -1)
        end,
        on_wheel = function(delta)
            cycle_track('sub', delta > 0 and 1 or -1)
        end,
        on_shift_click = function(button)
            if button == 'left' and actions:has('select_subtitle') then
                actions:select_subtitle()
            elseif button == 'left' then
                show_message('Subtitle selector unavailable')
            elseif button == 'right' then
                cycle_track('sub', 1)
            end
        end,
        tooltip = track_tooltip(snapshot, 'sub'),
        disabled_tooltip = 'No subtitles available',
    })
    local volume = snapshot_number(snapshot, 'volume') or 0
    local volume_icon
    if snapshot and snapshot:get('mute') == true then
        volume_icon = 'volume_off'
    elseif volume >= 75 then
        volume_icon = 'volume_up'
    elseif volume <= 0 then
        volume_icon = 'volume_mute'
    else
        volume_icon = 'volume_down'
    end
    add_side('volume', 'toggle_mute', volume_icon, {
        enabled = actions:has('toggle_mute'),
        on_right_click = function()
            if actions:has('select_audio_device') then
                actions:select_audio_device()
            else
                show_message('Audio-device selector unavailable')
            end
        end,
        on_wheel = function(delta)
            local current = snapshot_number(snapshot, 'volume') or 0
            local maximum = snapshot_number(snapshot, 'volume_max') or 100
            if actions:has('set_volume') then
                actions:set_volume(max(0, min(maximum, current + (delta > 0 and 5 or -5))))
            end
        end,
    })

    local stats_capability = capability_info(snapshot, 'stats')
    local stats_available = stats_capability == nil
        or stats_capability.status == 'available'
    local yt_dlp_capability = capability_info(snapshot, 'yt_dlp')
    local yt_dlp_available = yt_dlp_capability ~= nil
        and yt_dlp_capability.status == 'available'
    local download_capability = capability_info(snapshot, 'download')
    local download_available = yt_dlp_available and (download_capability == nil
        or download_capability.status == 'available'
        or download_capability.status == 'error')
    local download_tooltip = 'Download'
    if yt_dlp_capability == nil then
        download_tooltip = 'Download unavailable'
    elseif yt_dlp_capability.status == 'loading' then
        download_tooltip = 'Download capability is loading'
    elseif yt_dlp_capability.status == 'error' then
        download_tooltip = 'Download unavailable: '
            .. (yt_dlp_capability.error or yt_dlp_capability.detail or 'probe failed')
    elseif not yt_dlp_available then
        download_tooltip = 'Download unavailable'
    elseif download_capability then
        if download_capability.status == 'loading' then
            download_tooltip = 'Downloading...'
        elseif download_capability.status == 'available' and download_capability.detail == 'downloaded' then
            download_tooltip = 'Already downloaded'
        elseif download_capability.status == 'error' then
            download_tooltip = 'Download failed: '
                .. (download_capability.error or download_capability.detail or 'unavailable')
        elseif download_capability.status == 'unavailable' then
            download_tooltip = 'Download unavailable'
        end
    end
    local right_icons = {
        { name = 'fullscreen', action = 'toggle_fullscreen',
            icon = snapshot and snapshot:get('fullscreen') == true
                and 'close_fullscreen' or 'open_in_full' },
        { name = 'loop', action = 'toggle_loop',
            icon = snapshot and snapshot:get('loop_file') == true and 'loop_on' or 'loop',
            tooltip = snapshot and snapshot:get('loop_file') == true and 'Disable loop' or 'Loop' },
        { name = 'ontop', action = 'toggle_ontop',
            icon = snapshot and snapshot:get('ontop') == true and 'pinned' or 'unpinned',
            tooltip = snapshot and snapshot:get('ontop') == true and 'Unpin window' or 'Keep on top' },
        { name = 'info', action = nil, icon = 'info', callback = function()
            if actions:has('show_stats') then
                actions:show_stats()
            end
        end, enabled = actions:has('show_stats') and stats_available,
            tooltip = 'Player information', disabled_tooltip = 'Information unavailable' },
        { name = 'screenshot', action = nil, icon = 'screenshot', callback = function()
            if actions:has('screenshot') then
                actions:screenshot(theme.screenshot_flag)
            end
        end, enabled = actions:has('screenshot'), tooltip = 'Screenshot',
            disabled_tooltip = 'Screenshot unavailable' },
        { name = 'download', action = nil,
            icon = download_capability and download_capability.status == 'available'
                and download_capability.detail == 'downloaded' and 'download_done' or 'download',
            callback = function()
                local source = player_metadata.source(snapshot)
                if actions:has('download') and source then
                    actions:download(source)
                elseif actions:has('show_message') then
                    actions:show_message('Download URL unavailable')
                end
            end, enabled = actions:has('download') and is_url and download_available,
            tooltip = download_tooltip, disabled_tooltip = download_tooltip },
    }
    for _, item in ipairs(right_icons) do
        local name = item.name
        local item_rect = layout_geometry.right[name]
        if item_rect and layout_geometry.visibility[name] then
            local action = item.action
            children[#children + 1] = positioned(item_rect, icon_control(
                theme, actions, name, action, item.icon, item_rect,
                theme.side_button_size, theme.side_button_color, item.callback, nil,
                bounded_interaction(item, item_rect)))
        end
    end
    if extra_right_control and layout_geometry.visibility.extra_right_control then
        children[#children + 1] = positioned(layout_geometry.right.extra_right_control, extra_right_control)
    end
    return children
end

M.default_controller = default_controller

return M
