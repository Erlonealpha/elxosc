-- ModernX-oriented player layout and visual intent.

local std = require 'elxlibs.std'
local color_mod = require 'foundation.color'
local widget_mod = require 'widget.widget'

local Color = color_mod.Color
local InheritedWidget = widget_mod.InheritedWidget
local raise = std.raise

local M = {}

---@alias PlayerLayoutOption
---| 'original'
---| 'reduced'

---@alias PlayerWindowTopBarMode
---| 'auto'
---| 'yes'
---| 'no'

local function finite(name, value)
    if type(value) ~= 'number' or value ~= value
        or value == math.huge or value == -math.huge then
        raise(std.ValueError('PlayerThemeData.' .. name .. ' must be finite'))
    end
    return value
end

local function non_negative(name, value)
    value = finite(name, value)
    if value < 0 then
        raise(std.ValueError('PlayerThemeData.' .. name .. ' must be non-negative'))
    end
    return value
end

local function positive(name, value)
    value = finite(name, value)
    if value <= 0 then
        raise(std.ValueError('PlayerThemeData.' .. name .. ' must be positive'))
    end
    return value
end

local function boolean(name, value)
    if type(value) ~= 'boolean' then
        raise(std.TypeError('PlayerThemeData.' .. name .. ' must be a boolean'))
    end
    return value
end

local function colour(name, value)
    if not std.isinstance(value, Color) then
        raise(std.TypeError('PlayerThemeData.' .. name .. ' must be a Color'))
    end
    return value
end

local function pick(value, default)
    if value == nil then
        return default
    end
    return value
end

---@class _PlayerThemeDataOptions
---@field layout_option PlayerLayoutOption?
---@field window_top_bar PlayerWindowTopBarMode?
---@field controller_height number?
---@field window_bar_height number?
---@field window_control_box_width number?
---@field window_control_width number?
---@field window_control_height number?
---@field title_font_size number?
---@field description_font_size number?
---@field time_font_size number?
---@field playpause_size number?
---@field middle_button_size number?
---@field side_button_size number?
---@field window_control_size number?
---@field seekbar_height number?
---@field progress_bar_height number?
---@field persistent_progress_height number?
---@field volume_width number?
---@field show_title boolean?
---@field show_description boolean?
---@field show_chapter_title boolean?
---@field volume_control boolean?
---@field compact_mode boolean?
---@field jump_buttons boolean?
---@field chapter_skip_buttons boolean?
---@field track_nextprev_buttons boolean?
---@field info_button boolean?
---@field ontop_button boolean?
---@field screenshot_button boolean?
---@field download_button boolean?
---@field loop_button boolean?
---@field persistent_progress boolean?
---@field window_title boolean?
---@field window_controls boolean?
---@field window_control_color Color?
---@field controller_color Color?
---@field controller_border_color Color?
---@field controller_blur_radius number?
---@field window_color Color?
---@field window_border_color Color?
---@field window_blur_radius number?
---@field title_color Color?
---@field description_color Color?
---@field time_color Color?
---@field chapter_color Color?
---@field seekbar_track_color Color?
---@field seekbar_buffer_color Color?
---@field seekbar_progress_color Color?
---@field side_button_color Color?
---@field middle_button_color Color?
---@field playpause_color Color?
---@field volume_track_color Color?
---@field volume_progress_color Color?
---@field hover_color Color?
---@field pressed_color Color?
---@field held_color Color?
---@field hover_scale number?

---@class PlayerThemeData : std.object
---@field layout_option PlayerLayoutOption
---@field window_top_bar PlayerWindowTopBarMode
---@field controller_height number
---@field window_bar_height number
---@field window_control_box_width number
---@field window_control_width number
---@field window_control_height number
---@field title_font_size number
---@field description_font_size number
---@field time_font_size number
---@field playpause_size number
---@field middle_button_size number
---@field side_button_size number
---@field window_control_size number
---@field seekbar_height number
---@field progress_bar_height number
---@field persistent_progress_height number
---@field volume_width number
---@field show_title boolean
---@field show_description boolean
---@field show_chapter_title boolean
---@field volume_control boolean
---@field compact_mode boolean
---@field jump_buttons boolean
---@field chapter_skip_buttons boolean
---@field track_nextprev_buttons boolean
---@field info_button boolean
---@field ontop_button boolean
---@field screenshot_button boolean
---@field download_button boolean
---@field loop_button boolean
---@field persistent_progress boolean
---@field window_title boolean
---@field window_controls boolean
---@field window_control_color Color
---@field controller_color Color
---@field controller_border_color Color
---@field controller_blur_radius number
---@field window_color Color
---@field window_border_color Color
---@field window_blur_radius number
---@field title_color Color
---@field description_color Color
---@field time_color Color
---@field chapter_color Color
---@field seekbar_track_color Color
---@field seekbar_buffer_color Color
---@field seekbar_progress_color Color
---@field side_button_color Color
---@field middle_button_color Color
---@field playpause_color Color
---@field volume_track_color Color
---@field volume_progress_color Color
---@field hover_color Color
---@field pressed_color Color
---@field held_color Color
---@field hover_scale number
---@overload fun(options?: _PlayerThemeDataOptions): self
local PlayerThemeData = std.class.new('PlayerThemeData', {})

function PlayerThemeData:__init(options)
    options = options or {}
    if type(options) ~= 'table' then
        raise(std.TypeError('PlayerThemeData expects an options table'))
    end

    self.layout_option = pick(options.layout_option, 'original')
    if self.layout_option ~= 'original' and self.layout_option ~= 'reduced' then
        raise(std.ValueError('PlayerThemeData.layout_option must be original or reduced'))
    end
    self.window_top_bar = pick(options.window_top_bar, 'auto')
    if self.window_top_bar ~= 'auto' and self.window_top_bar ~= 'yes'
        and self.window_top_bar ~= 'no' then
        raise(std.ValueError('PlayerThemeData.window_top_bar must be auto, yes or no'))
    end

    self.controller_height = positive('controller_height', pick(options.controller_height, 180))
    self.window_bar_height = positive('window_bar_height', pick(options.window_bar_height, 60))
    self.window_control_box_width = positive(
        'window_control_box_width', pick(options.window_control_box_width, 138))
    self.window_control_width = positive(
        'window_control_width', pick(options.window_control_width, 40))
    self.window_control_height = positive(
        'window_control_height', pick(options.window_control_height, 30))
    self.title_font_size = positive('title_font_size', pick(options.title_font_size, 28))
    self.description_font_size = positive(
        'description_font_size', pick(options.description_font_size, 19))
    self.time_font_size = positive('time_font_size', pick(options.time_font_size, 18))
    self.playpause_size = positive('playpause_size', pick(options.playpause_size, 30))
    self.middle_button_size = positive(
        'middle_button_size', pick(options.middle_button_size, 24))
    self.side_button_size = positive('side_button_size', pick(options.side_button_size, 24))
    self.window_control_size = positive(
        'window_control_size', pick(options.window_control_size, 18))
    self.seekbar_height = positive('seekbar_height', pick(options.seekbar_height, 2))
    self.progress_bar_height = positive(
        'progress_bar_height', pick(options.progress_bar_height, 16))
    self.persistent_progress_height = positive(
        'persistent_progress_height', pick(options.persistent_progress_height, 17))
    self.volume_width = positive('volume_width', pick(options.volume_width, 80))

    self.show_title = boolean('show_title', pick(options.show_title, true))
    self.show_description = boolean('show_description', pick(options.show_description, true))
    self.show_chapter_title = boolean(
        'show_chapter_title', pick(options.show_chapter_title, true))
    self.volume_control = boolean('volume_control', pick(options.volume_control, true))
    self.compact_mode = boolean('compact_mode', pick(options.compact_mode, true))
    self.jump_buttons = boolean('jump_buttons', pick(options.jump_buttons, true))
    self.chapter_skip_buttons = boolean(
        'chapter_skip_buttons', pick(options.chapter_skip_buttons, true))
    self.track_nextprev_buttons = boolean(
        'track_nextprev_buttons', pick(options.track_nextprev_buttons, true))
    self.info_button = boolean('info_button', pick(options.info_button, false))
    self.ontop_button = boolean('ontop_button', pick(options.ontop_button, true))
    self.screenshot_button = boolean('screenshot_button', pick(options.screenshot_button, false))
    self.download_button = boolean('download_button', pick(options.download_button, true))
    self.loop_button = boolean('loop_button', pick(options.loop_button, false))
    self.persistent_progress = boolean(
        'persistent_progress', pick(options.persistent_progress, false))
    self.window_title = boolean('window_title', pick(options.window_title, true))
    self.window_controls = boolean('window_controls', pick(options.window_controls, true))

    self.controller_color = colour(
        'controller_color', pick(options.controller_color, Color.rgba255(0, 0, 0, 180)))
    self.controller_border_color = colour(
        'controller_border_color',
        pick(options.controller_border_color, Color.rgba255(29, 150, 245, 70)))
    self.controller_blur_radius = non_negative(
        'controller_blur_radius', pick(options.controller_blur_radius, 75))
    self.window_color = colour(
        'window_color', pick(options.window_color, Color.rgba255(0, 0, 0, 180)))
    self.window_border_color = colour(
        'window_border_color',
        pick(options.window_border_color, Color.rgba255(29, 150, 245, 70)))
    self.window_blur_radius = non_negative(
        'window_blur_radius', pick(options.window_blur_radius, 75))
    self.window_control_color = colour(
        'window_control_color', pick(options.window_control_color, Color.hex('#FFFFFF')))
    self.title_color = colour('title_color', pick(options.title_color, Color.hex('#FFFFFF')))
    self.description_color = colour(
        'description_color', pick(options.description_color, Color.hex('#FFFFFF')))
    self.time_color = colour('time_color', pick(options.time_color, Color.hex('#FFFFFF')))
    self.chapter_color = colour('chapter_color', pick(options.chapter_color, Color.hex('#FFFFFF')))
    self.seekbar_track_color = colour(
        'seekbar_track_color', pick(options.seekbar_track_color, Color.rgba255(255, 255, 255, 128)))
    self.seekbar_buffer_color = colour(
        'seekbar_buffer_color', pick(options.seekbar_buffer_color, Color.rgba255(29, 150, 245, 128)))
    self.seekbar_progress_color = colour(
        'seekbar_progress_color', pick(options.seekbar_progress_color, Color.hex('#1D96F5')))
    self.side_button_color = colour(
        'side_button_color', pick(options.side_button_color, Color.hex('#FFFFFF')))
    self.middle_button_color = colour(
        'middle_button_color', pick(options.middle_button_color, Color.hex('#FFFFFF')))
    self.playpause_color = colour(
        'playpause_color', pick(options.playpause_color, Color.hex('#FFFFFF')))
    self.volume_track_color = colour(
        'volume_track_color', pick(options.volume_track_color, Color.hex('#999999')))
    self.volume_progress_color = colour(
        'volume_progress_color', pick(options.volume_progress_color, Color.hex('#FFFFFF')))
    self.hover_color = colour(
        'hover_color', pick(options.hover_color, Color.rgba255(255, 255, 255, 40)))
    self.pressed_color = colour(
        'pressed_color', pick(options.pressed_color, Color.rgba255(153, 153, 153, 90)))
    self.held_color = colour(
        'held_color', pick(options.held_color, Color.hex('#999999')))
    self.hover_scale = positive('hover_scale', pick(options.hover_scale, 1.15))
end

---@param options _PlayerThemeDataOptions?
---@return PlayerThemeData
function PlayerThemeData:copy_with(options)
    local values = {}
    for key, value in pairs(self) do
        values[key] = value
    end
    for key, value in pairs(options or {}) do
        values[key] = value
    end
    return PlayerThemeData(values)
end

---@class _PlayerThemeOptions
---@field data PlayerThemeData
---@field child Widget?
---@field key any?

---@class PlayerTheme : InheritedWidget
---@field data PlayerThemeData
---@field child Widget?
---@overload fun(options: _PlayerThemeOptions): self
local PlayerTheme = std.class.new('PlayerTheme', { InheritedWidget })
local PlayerThemeClass = PlayerTheme --[[@as std.Class]]

function PlayerTheme:__init(options)
    if type(options) ~= 'table' then
        raise(std.TypeError('PlayerTheme expects an options table'))
    end
    self.key = options.key
    self.data = options.data or PlayerThemeData()
    self.child = options.child
    if not std.isinstance(self.data, PlayerThemeData) then
        raise(std.TypeError('PlayerTheme.data must be PlayerThemeData'))
    end
end

function PlayerTheme:update_should_notify(old_widget)
    return self.data ~= old_widget.data
end

---@param context BuildContext
---@return PlayerTheme
function PlayerTheme.of(context)
    local value = context:depend_on_inherited_widget_of_exact_type(PlayerThemeClass)
    if value == nil then
        raise(std.RuntimeError('no PlayerTheme ancestor was found'))
    end
    return value --[[@as PlayerTheme]]
end

---@param context BuildContext
---@return PlayerTheme?
function PlayerTheme.maybe_of(context)
    return context:depend_on_inherited_widget_of_exact_type(PlayerThemeClass) --[[@as PlayerTheme?]]
end

M.PlayerThemeData = PlayerThemeData
M.PlayerTheme = PlayerTheme

return M
