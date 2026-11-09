-- Finite root-relative geometry for ModernX layout profiles.

local std = require 'elxlibs.std'
local geometry = require 'foundation.geometry'

local Rect = geometry.Rect

local raise = std.raise
local max = math.max
local min = math.min
local huge = math.huge

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
            0,
            viewport_width,
            options.window_control_height or 30),
        window_title = safe_rect(12, 0, viewport_width - 150, 30),
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

    local function control_count(name)
        local count = non_negative(name, options[name] or 0)
        if count % 1 ~= 0 then
            raise(std.ValueError('PlayerLayout.' .. name .. ' must be an integer'))
        end
        return count
    end
    local left_count = control_count('left_control_count')
    local right_count = control_count('right_control_count')
    local center_left, center_right = viewport_width, 0
    for _, bounds in pairs(result.center) do
        center_left = min(center_left, bounds.left)
        center_right = max(center_right, bounds.right)
    end

    local right_center = viewport_width - 37
    local function right_control(name, enabled, threshold)
        if enabled then
            result.right[name] = centered(right_center, center_y, 24, 24)
            result.visibility[name] = viewport_width >= threshold - outeroffset
                and (not result.visibility.right_controls or result.right[name].left >= center_right + 21)
            right_center = right_center - 45
        end
    end
    right_control('fullscreen', true, 250)
    right_control('loop', options.loop_button == true, 600)
    right_control('ontop', options.ontop_button ~= false, 700)
    if right_count > 0 then
        local bounds = rect(right_center - 12 - (right_count - 1) * 45, center_y - 12,
            24 + (right_count - 1) * 45, 24)
        result.right.right_controls = bounds
        result.visibility.right_controls = bounds.left >= center_right + 21
        if result.visibility.right_controls then
            right_center = right_center - right_count * 45
        end
    end
    right_control('info', options.info_button == true, 500)
    right_control('screenshot', options.screenshot_button == true, 300)
    right_control('download', options.download_button == true and options.is_url == true, 400)

    result.visibility.audio = viewport_width >= 500 - outeroffset
    result.visibility.subtitle = viewport_width >= 600 - outeroffset
    result.visibility.volume = viewport_width >= 700 - outeroffset
    result.visibility.volume_slider = viewport_width >= 900 - outeroffset
    result.visibility.volume_control = options.volume_control ~= false
    if left_count > 0 then
        local left_center = 37
        if result.visibility.subtitle then
            left_center = 127
        elseif result.visibility.audio then
            left_center = 82
        end
        if result.visibility.volume_control and result.visibility.volume then
            left_center = 172
        end
        if result.visibility.volume_control and result.visibility.volume_slider then
            left_center = result.volume.right + 33
        end
        local bounds = rect(left_center - 12, center_y - 12, 24 + (left_count - 1) * 45, 24)
        result.side.left_controls = bounds
        result.visibility.left_controls = bounds.right <= center_left - 21
    end
    result.visibility.title = options.show_title ~= false
    result.visibility.chapter = options.show_chapter_title ~= false
    result.visibility.description = options.has_description == true and options.show_description ~= false
    result.visibility.persistent_progress = options.persistent_progress == true
    return result
end

M.geometry_for = geometry_for

return M
