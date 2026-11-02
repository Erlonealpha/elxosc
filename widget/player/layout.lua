-- Root-relative ModernX original/reduced player geometry and composition.

local std = require 'elxlibs.std'
local geometry = require 'foundation.geometry'
local text_style_mod = require 'text.text_style'
local ambient_mod = require 'widget.ambient'
local actions_mod = require 'widget.actions'
local basic_widgets = require 'widget.widgets.basic'
local layout_widgets = require 'widget.widgets.layout'
local widget_mod = require 'widget.widget'
local theme_mod = require 'widget.player.theme'
local icon_map = require 'widget.player.icon_map'
local progress_mod = require 'widget.player.progress_bar'
local tooltip_mod = require 'widget.player.tooltip'
local metadata_mod = require 'widget.player.metadata'

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
local Column = layout_widgets.Column
local OffsetBox = layout_widgets.OffsetBox
local Text = basic_widgets.Text
local IconButton = basic_widgets.IconButton
local CustomPaint = basic_widgets.CustomPaint
local GestureDetector = basic_widgets.GestureDetector
local ButtonStyle = basic_widgets.ButtonStyle
local PlayerThemeData = theme_mod.PlayerThemeData
local Icon = icon_map.icon
local ProgressBar = progress_mod.ProgressBar
local PlayerTooltip = tooltip_mod.PlayerTooltip
local player_metadata = metadata_mod
local StatelessWidget = widget_mod.StatelessWidget
local StatefulWidget = widget_mod.StatefulWidget
local State = require('widget.state').State

local raise = std.raise
local max = math.max
local min = math.min
local huge = math.huge
local Color = require 'foundation.color'.Color
local Paint = require 'painting.paint'.Paint
local PaintStyle = require 'painting.paint'.Style
local ColorTransparent = Color.rgba255(0, 0, 0, 0)
local ColorBlack = Color.rgba255(0, 0, 0, 255)
local SPONSOR_COLORS = {
    sponsor = Color.hex('#6BCB77'),
    intro = Color.hex('#FFD166'),
    outro = Color.hex('#4D96FF'),
    interaction = Color.hex('#C77DFF'),
    selfpromo = Color.hex('#FF9F1C'),
    preview = Color.hex('#00B4D8'),
    filler = Color.hex('#8D99AE'),
}

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
    result.visibility.volume_slider = viewport_width >= 900 - outeroffset
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

---@param snapshot PlayerSnapshot?
---@param name string
---@return boolean
local function capability_available(snapshot, name)
    if snapshot == nil or type(snapshot.capability) ~= 'function' then
        return false
    end
    return snapshot:capability(name).status == 'available'
end

---@param snapshot PlayerSnapshot?
---@param name string
---@return CapabilityInfo?
local function capability_info(snapshot, name)
    if snapshot == nil then
        return nil
    end
    local capabilities = snapshot:get('capabilities')
    if type(capabilities) ~= 'table' or capabilities[name] == nil
        or type(snapshot.capability) ~= 'function' then
        return nil
    end
    return snapshot:capability(name)
end

---@param theme PlayerThemeData
---@param title string
---@return Widget
local function idle_view(theme, title)
    local label = title ~= '' and title ~= 'elxosc' and title or 'No media loaded'
    return Container({
        alignment = Offset(0.5, 0.45),
        child = Column({
            main_alignment = 'center',
            cross_alignment = 'center',
            children = {
                Icon('idle', { color = theme.title_color }),
                Text(label, { style = TextStyle({
                    font_size = theme.title_font_size,
                    color = theme.title_color,
                    align = 'center',
                    wrap = false,
                }) }),
                Text('Drop a file or open a media URL', { style = TextStyle({
                    font_size = theme.description_font_size,
                    color = theme.description_color,
                    align = 'center',
                    wrap = false,
                }) }),
            },
        }),
    })
end

---@class _PlayerDescriptionLayerOptions
---@field theme PlayerThemeData
---@field text string
---@field preview string
---@field bounds Rect
---@field viewport_width number
---@field viewport_height number
---@field actions HostActions
---@field links string[]
---@field stats string
---@field key any?

---@class PlayerDescriptionLayer : StatefulWidget
---@field theme PlayerThemeData
---@field text string
---@field preview string
---@field bounds Rect
---@field viewport_width number
---@field viewport_height number
---@field actions HostActions
---@field links string[]
---@field stats string
---@overload fun(options: _PlayerDescriptionLayerOptions): self
local PlayerDescriptionLayer = std.class.new('PlayerDescriptionLayer', { StatefulWidget })

function PlayerDescriptionLayer:__init(options)
    options = options or {}
    self.key = options.key or 'player-description-layer'
    self.theme = options.theme
    self.text = options.text or ''
    self.preview = options.preview or ''
    self.bounds = options.bounds
    self.viewport_width = options.viewport_width
    self.viewport_height = options.viewport_height
    self.actions = options.actions or HostActions()
    self.links = options.links or {}
    self.stats = options.stats or ''
end

---@class PlayerDescriptionLayerState : State
---@field open boolean
---@field scroll number
---@field selected_link integer
---@overload fun(): self
local PlayerDescriptionLayerState = std.class.new('PlayerDescriptionLayerState', { State })

function PlayerDescriptionLayerState:init_state()
    self.open = false
    self.scroll = 0
    self.selected_link = 1
end

function PlayerDescriptionLayerState:did_update_widget(old_widget)
    local widget = self.widget --[[@as PlayerDescriptionLayer]]
    if old_widget.text ~= widget.text then
        self.open = false
        self.scroll = 0
        self.selected_link = 1
    end
end

---@param event KeyEvent|string
---@return boolean
function PlayerDescriptionLayerState:handle_key(event)
    if not self.open then
        return false
    end
    local key = type(event) == 'string' and event or event and event.key
    local event_type = type(event) == 'table' and event.type or 'press'
    if event_type ~= 'down' and event_type ~= 'press' then
        return false
    end
    local widget = self.widget --[[@as PlayerDescriptionLayer]]
    if key == 'ESC' or key == 'ESCAPE' or key == 'escape' then
        self:set_state(function()
            self.open = false
            self.scroll = 0
            self.selected_link = 1
        end)
        return true
    end
    if key == 'TAB' or key == 'tab' then
        if #widget.links == 0 then
            return true
        end
        local backwards = type(event) == 'table' and event.modifiers
            and event.modifiers.shift == true
        self:set_state(function()
            if backwards then
                self.selected_link = self.selected_link - 1
                if self.selected_link < 1 then
                    self.selected_link = #widget.links
                end
            else
                self.selected_link = self.selected_link + 1
                if self.selected_link > #widget.links then
                    self.selected_link = 1
                end
            end
        end)
        return true
    end
    if key == 'ENTER' or key == 'enter' then
        local url = widget.links[self.selected_link]
        if url and widget.actions:has('open_url') then
            widget.actions:open_url(url)
        elseif widget.actions:has('show_message') then
            widget.actions:show_message('No link is selected')
        end
        return true
    end
    return false
end

---@return boolean
function PlayerDescriptionLayerState:can_handle_key()
    return self.open
end

function PlayerDescriptionLayerState:build()
    local widget = self.widget --[[@as PlayerDescriptionLayer]]
    local bounds = widget.bounds
    if not self.open then
        local text_style = TextStyle({
            font_size = widget.theme.description_font_size,
            color = widget.theme.description_color,
            blur_radius = 1,
            outline_width = 0.5,
            outline_color = ColorBlack,
            wrap = false,
            align = bounds.left < widget.viewport_width / 2 and 'left' or 'right',
        })
        return Stack({
            children = {
                Positioned({
                    left = bounds.left,
                    top = bounds.top,
                    width = bounds:width(),
                    height = bounds:height(),
                    child = GestureDetector(Text(widget.preview, { style = text_style }), {
                        on_tap = function()
                            self:set_state(function()
                                self.open = true
                                self.scroll = 0
                            end)
                        end,
                    }),
                }),
            },
        })
    end

    local panel_width = max(0, widget.viewport_width - 80)
    local panel_height = max(0, widget.viewport_height - 80)
    local panel_style = TextStyle({
        font_size = widget.theme.description_font_size,
        color = widget.theme.description_color,
        wrap = true,
        align = 'left',
    })
    local selected = widget.links[self.selected_link]
    local link_label = #widget.links > 0
        and string.format('Link %d/%d: %s', self.selected_link, #widget.links, selected)
        or 'No links found'
    local close = GestureDetector(Icon('close', { color = widget.theme.title_color }), {
        on_tap = function()
            self:set_state(function()
                self.open = false
                self.scroll = 0
            end)
        end,
    })
    local content = OffsetBox({
        offset = Offset(0, -self.scroll),
        child = Column({
            children = {
                widget.stats ~= '' and Text(widget.stats, { style = TextStyle({
                    font_size = max(12, widget.theme.description_font_size - 2),
                    color = widget.theme.chapter_color,
                    wrap = false,
                }) }) or SizedBox.shrink(),
                Text(link_label, { style = TextStyle({
                    font_size = max(12, widget.theme.description_font_size - 2),
                    color = widget.theme.chapter_color,
                    wrap = false,
                }) }),
                Text(widget.text, { style = panel_style }),
            },
        }),
    })
    return GestureDetector(Stack({
        children = {
            Container({
                width = widget.viewport_width,
                height = widget.viewport_height,
                color = Color.rgba255(0, 0, 0, 205),
            }),
            Positioned({
                left = 40,
                top = 40,
                width = panel_width,
                height = panel_height,
                child = Container({
                    padding = EdgeInsets.all(20),
                    color = Color.rgba255(20, 20, 20, 235),
                    child = content,
                }),
            }),
            Positioned({
                left = widget.viewport_width - 64,
                top = 20,
                width = 32,
                height = 32,
                child = close,
            }),
        },
    }), {
        on_wheel = function(_, delta)
            local amount = type(delta) == 'number' and delta or 0
            self:set_state(function()
                self.scroll = max(0, min(2000, self.scroll - amount * 32))
            end)
            return true
        end,
    })
end

function PlayerDescriptionLayer:create_state()
    return PlayerDescriptionLayerState()
end

---@param source table?
---@return any[]
local function array_items(source)
    local values = {}
    if type(source) ~= 'table' then
        return values
    end
    local index = 1
    while source[index] ~= nil do
        values[#values + 1] = source[index]
        index = index + 1
    end
    return values
end

---@param snapshot PlayerSnapshot?
---@return table[]
local function chapter_entries(snapshot)
    local source = snapshot and snapshot:get('chapter_list') or nil
    if type(source) ~= 'table' then
        return {}
    end
    local entries = {}
    for _, chapter in ipairs(array_items(source)) do
        if type(chapter) == 'table' then
            entries[#entries + 1] = chapter
        end
    end
    table.sort(entries, function(left, right)
        return (tonumber(left.time) or huge) < (tonumber(right.time) or huge)
    end)
    return entries
end

---@param snapshot PlayerSnapshot?
---@return string
local function current_chapter_title(snapshot)
    if snapshot and snapshot:get('buffering') == true then
        return 'Buffering...'
    end
    local explicit = snapshot_text(snapshot, { 'chapter_title' }, '')
    if explicit ~= '' then
        return explicit
    end
    local index = snapshot_number(snapshot, 'chapter')
    local chapters = chapter_entries(snapshot)
    if index == nil or #chapters == 0 or index < 0 then
        return ''
    end
    local chapter = chapters[index + 1]
    if type(chapter) == 'table' and type(chapter.title) == 'string' and chapter.title ~= '' then
        return chapter.title
    end
    return ''
end

local function clamp_fraction(value)
    return max(0, min(1, value))
end

local function format_time(value, show_milliseconds, fixed)
    if value == nil or value < 0 then
        return '--:--'
    end
    local total = math.floor(value)
    local seconds = total % 60
    local minutes = math.floor(total / 60) % 60
    local hours = math.floor(total / 3600)
    local milliseconds = math.floor((value - total) * 1000 + 0.5)
    if milliseconds >= 1000 then
        seconds = seconds + 1
        milliseconds = 0
    end
    if show_milliseconds then
        if hours > 0 or fixed then
            return string.format('%02d:%02d:%02d.%03d', hours, minutes, seconds, milliseconds)
        end
        return string.format('%02d:%02d.%03d', minutes, seconds, milliseconds)
    end
    if fixed and hours == 0 then
        return string.format('00:%02d:%02d', minutes, seconds)
    end
    if hours > 0 then
        return string.format('%d:%02d:%02d', hours, minutes, seconds)
    end
    return string.format('%02d:%02d', minutes, seconds)
end

---@param snapshot PlayerSnapshot?
---@param fraction number
---@param duration number?
---@return string?
local function chapter_title_at_fraction(snapshot, fraction, duration)
    if duration == nil or duration <= 0 then
        return nil
    end
    local selected
    for index, chapter in ipairs(chapter_entries(snapshot)) do
        local time = tonumber(chapter.time)
        if time and time <= fraction * duration then
            selected = { chapter = chapter, index = index }
        elseif time and time > fraction * duration then
            break
        end
    end
    if not selected then
        return nil
    end
    local title = selected.chapter.title
    if type(title) == 'string' and title ~= '' then
        return title
    end
    return nil
end

---@class _PlayerTimeDisplayOptions
---@field value number?
---@field duration number?
---@field show_remaining boolean?
---@field show_milliseconds boolean?
---@field unicode_minus boolean?
---@field fixed boolean?
---@field toggle_mode 'milliseconds'|'remaining'
---@field suffix string?
---@field style TextStyle
---@field alignment Offset
---@field key any?

---@class PlayerTimeDisplay : StatefulWidget
---@field value number?
---@field duration number?
---@field show_remaining boolean
---@field show_milliseconds boolean
---@field unicode_minus boolean
---@field fixed boolean
---@field toggle_mode 'milliseconds'|'remaining'
---@field suffix string
---@field style TextStyle
---@field alignment Offset
---@overload fun(options: _PlayerTimeDisplayOptions): self
local PlayerTimeDisplay = std.class.new('PlayerTimeDisplay', { StatefulWidget })

function PlayerTimeDisplay:__init(options)
    options = options or {}
    self.key = options.key
    self.value = options.value
    self.duration = options.duration
    self.show_remaining = options.show_remaining == true
    self.show_milliseconds = options.show_milliseconds == true
    self.unicode_minus = options.unicode_minus == true
    self.fixed = options.fixed == true
    self.toggle_mode = options.toggle_mode or 'milliseconds'
    if self.toggle_mode ~= 'milliseconds' and self.toggle_mode ~= 'remaining' then
        raise(std.ValueError('PlayerTimeDisplay.toggle_mode is invalid'))
    end
    self.style = options.style
    self.alignment = options.alignment or Offset(0.5, 0.5)
    self.suffix = options.suffix or ''
end

---@class PlayerTimeDisplayState : State
---@field show_remaining boolean
---@field show_milliseconds boolean
---@overload fun(): self
local PlayerTimeDisplayState = std.class.new('PlayerTimeDisplayState', { State })

function PlayerTimeDisplayState:init_state()
    local widget = self.widget --[[@as PlayerTimeDisplay]]
    self.show_remaining = widget.show_remaining
    self.show_milliseconds = widget.show_milliseconds
end

function PlayerTimeDisplayState:did_update_widget(old_widget)
    local widget = self.widget --[[@as PlayerTimeDisplay]]
    if old_widget.show_remaining ~= widget.show_remaining then
        self.show_remaining = widget.show_remaining
    end
    if old_widget.show_milliseconds ~= widget.show_milliseconds then
        self.show_milliseconds = widget.show_milliseconds
    end
end

function PlayerTimeDisplayState:build()
    local widget = self.widget --[[@as PlayerTimeDisplay]]
    local value = widget.value
    local prefix = ''
    local label
    if value == nil then
        value = 0
        label = '--:--'
    elseif widget.toggle_mode == 'remaining' then
        if self.show_remaining then
            value = (widget.duration or 0) - value
        else
            value = widget.duration
        end
        if value == nil then
            label = '--:--'
            value = 0
        end
        if self.show_remaining and value > 0 then
            prefix = widget.unicode_minus and '−' or '-'
        else
            value = math.abs(value)
        end
    end
    if label == nil then
        label = prefix .. format_time(value, self.show_milliseconds, widget.fixed)
    end
    label = label .. widget.suffix
    return GestureDetector(Container({
        alignment = widget.alignment,
        child = Text(label, { style = widget.style }),
    }), {
        on_enter = function() end,
        on_leave = function() end,
        on_tap = function()
            self:set_state(function()
                if widget.toggle_mode == 'remaining' then
                    self.show_remaining = not self.show_remaining
                else
                    self.show_milliseconds = not self.show_milliseconds
                end
            end)
        end,
    })
end

function PlayerTimeDisplay:create_state()
    return PlayerTimeDisplayState()
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

---@param snapshot PlayerSnapshot?
---@param duration number?
---@return table[]
local function chapter_markers(snapshot, duration)
    local chapters = chapter_entries(snapshot)
    if #chapters == 0 or duration == nil or duration <= 0 then
        return {}
    end
    local current = snapshot_number(snapshot, 'chapter')
    local markers = {}
    for index, chapter in ipairs(chapters) do
        if type(chapter) == 'table' then
            local time = tonumber(chapter.time)
            if time and time >= 0 then
                markers[#markers + 1] = {
                    fraction = clamp_fraction(time / duration),
                    current = current ~= nil and current == index - 1,
                    index = index - 1,
                }
            end
        end
    end
    return markers
end

---@param snapshot PlayerSnapshot?
---@param duration number?
---@return table[]
local function seek_ranges(snapshot, duration)
    if snapshot == nil or duration == nil or duration <= 0 then
        return {}
    end
    local source = snapshot:get('seekable_ranges')
    if source == nil then
        local cache_state = snapshot:get('cache_state')
        source = type(cache_state) == 'table' and cache_state['seekable-ranges'] or nil
    end
    if type(source) ~= 'table' then
        return {}
    end
    local ranges = {}
    for _, range in ipairs(array_items(source)) do
        if type(range) == 'table' then
            local start = tonumber(range.start or range[1])
            local finish = tonumber(range['end'] or range.finish or range[2])
            if start and finish then
                ranges[#ranges + 1] = {
                    start = clamp_fraction(start / duration),
                    ['end'] = clamp_fraction(finish / duration),
                }
            end
        end
    end
    return ranges
end

---@param snapshot PlayerSnapshot?
---@param duration number?
---@return table[]
local function sponsor_ranges(snapshot, duration)
    if snapshot == nil or duration == nil or duration <= 0 then
        return {}
    end
    local source = snapshot:get('sponsor_segments')
    if type(source) ~= 'table' then
        return {}
    end
    local ranges = {}
    for _, segment in ipairs(array_items(source)) do
        if type(segment) == 'table' then
            local start = tonumber(segment.start or segment[1])
            local finish = tonumber(segment['end'] or segment.finish or segment[2])
            if start and finish then
                ranges[#ranges + 1] = {
                    start = clamp_fraction(start / duration),
                    ['end'] = clamp_fraction(finish / duration),
                    color = SPONSOR_COLORS[segment.category],
                }
            end
        end
    end
    return ranges
end

---@param snapshot PlayerSnapshot?
---@param kind 'audio'|'sub'
---@return number[]
local function track_ids(snapshot, kind)
    local ids = {}
    local tracks = snapshot and snapshot:get('track_list') or nil
    if type(tracks) ~= 'table' then
        return ids
    end
    for _, track in ipairs(array_items(tracks)) do
        if type(track) == 'table' and track.type == kind then
            local id = tonumber(track.id)
            if id ~= nil then
                ids[#ids + 1] = id
            end
        end
    end
    table.sort(ids)
    return ids
end

---@param snapshot PlayerSnapshot?
---@param kind 'audio'|'sub'
---@return number
local function current_track(snapshot, kind)
    local tracks = snapshot and snapshot:get('track_list') or nil
    if type(tracks) == 'table' then
        for _, track in ipairs(array_items(tracks)) do
            if type(track) == 'table' and track.type == kind and track.selected == true then
                return tonumber(track.id) or 0
            end
        end
    end
    return 0
end

---@param snapshot PlayerSnapshot?
---@param kind 'audio'|'sub'
---@return string
local function track_tooltip(snapshot, kind)
    local label = kind == 'audio' and 'Audio' or 'Subtitles'
    local unavailable = kind == 'audio' and 'No audio available' or 'No subtitles available'
    local tracks = snapshot and snapshot:get('track_list') or nil
    if type(tracks) ~= 'table' then
        return label
    end
    local matching = {}
    local selected
    for _, track in ipairs(array_items(tracks)) do
        if type(track) == 'table' and track.type == kind then
            matching[#matching + 1] = track
            if track.selected == true then
                selected = track
            end
        end
    end
    if #matching == 0 then
        return unavailable
    end
    if selected == nil then
        return label .. ' off'
    end
    local selected_data = selected --[[@as table<string, any>]]
    local id = tonumber(selected_data.id)
    local suffix = id and string.format(' [%d / %d]', id, #matching) or ''
    local language = type(selected_data.lang) == 'string' and selected_data.lang or ''
    local title = type(selected_data.title) == 'string' and selected_data.title or ''
    local details = language ~= '' and language or title
    if language ~= '' and title ~= '' then
        details = language .. ' ' .. title
    end
    if details ~= '' then
        suffix = suffix .. ' ' .. details
    end
    return label .. suffix
end

---@param snapshot PlayerSnapshot?
---@param kind 'audio'|'sub'
---@return string
local function track_list_message(snapshot, kind)
    local label = kind == 'audio' and 'Audio' or 'Subtitles'
    local tracks = snapshot and snapshot:get('track_list') or nil
    if type(tracks) ~= 'table' then
        return label .. ': unavailable'
    end
    local names = {}
    for index, track in ipairs(array_items(tracks)) do
        if type(track) == 'table' and track.type == kind then
            local id = tonumber(track.id) or index
            local title = type(track.title) == 'string' and track.title or ''
            local language = type(track.lang) == 'string' and track.lang or ''
            local details = title ~= '' and title or language
            names[#names + 1] = details ~= '' and (id .. ': ' .. details) or tostring(id)
        end
    end
    if #names == 0 then
        return label .. ': unavailable'
    end
    return label .. ': ' .. table.concat(names, ', ')
end

---@param snapshot PlayerSnapshot?
---@param kind 'audio'|'sub'
---@param delta number
---@return number?
local function next_track(snapshot, kind, delta)
    local ids = track_ids(snapshot, kind)
    if #ids == 0 then
        return nil
    end
    local current = current_track(snapshot, kind)
    local position = 0
    for index, id in ipairs(ids) do
        if id == current then
            position = index
            break
        end
    end
    if delta > 0 then
        position = position + 1
        if position > #ids then
            return 0
        end
        return ids[position]
    end
    position = position - 1
    if position <= 0 then
        return ids[#ids]
    end
    return ids[position]
end

---@param snapshot PlayerSnapshot?
---@param fraction number
---@param duration number?
---@return number?
local function nearest_chapter(snapshot, fraction, duration)
    local chapters = chapter_markers(snapshot, duration)
    local best, distance
    for index, marker in ipairs(chapters) do
        local current_distance = math.abs(marker.fraction - fraction)
        if distance == nil or current_distance < distance then
            distance = current_distance
            best = marker.index or index - 1
        end
    end
    return best
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

local function panel(theme, color, border_color, blur_radius, top)
    return CustomPaint({
        draw = function(canvas, offset, size)
            -- ModernX uses a one-pixel edge box with a large blur. Painting a
            -- full opaque controller rectangle first creates an extra gray
            -- layer over the intended gradient.
            local y = top and offset.y or offset.y + max(0, size.height - 1)
            local edge = Rect.from_ltwh(offset.x, y, size.width, 1)
            local fill = Paint(color)
            fill.blur_radius = blur_radius
            canvas:draw_rect(edge, fill)
            local border = Paint(border_color, PaintStyle.STROKE,
                top and theme.window_border_width or theme.controller_border_width)
            border.blur_radius = blur_radius
            canvas:draw_rect(edge, border)
        end,
    })
end

local function control_style(theme, hover_foreground_color, foreground_color)
    return ButtonStyle({
        background_color = ColorTransparent,
        hover_color = ColorTransparent,
        pressed_color = ColorTransparent,
        disabled_color = ColorTransparent,
        foreground_color = foreground_color or theme.side_button_color,
        hover_foreground_color = hover_foreground_color or foreground_color or theme.side_button_color,
        pressed_foreground_color = theme.held_color,
        disabled_foreground_color = theme.held_color,
        hover_shadow_color = theme.hover_glow_color,
        hover_shadow_radius = theme.button_glow_amount,
        padding = EdgeInsets.zero(),
        radius = 0,
        hover_scale = theme.hover_scale,
    })
end

local function icon_control(
    theme, actions, name, action_name, icon_name, item_rect, icon_size, color, custom_callback, style,
    interaction)
    interaction = interaction or {}
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
    local enabled = interaction.enabled ~= nil and interaction.enabled
        or (interaction.enabled == nil and (action_name == nil or actions:has(action_name)))
    local button = IconButton({
        key = 'player-' .. name,
        icon = hitbox,
        enabled = enabled,
        on_click = callback,
        on_right_click = interaction.on_right_click,
        on_shift_click = interaction.on_shift_click,
        on_wheel = interaction.on_wheel,
        soft_repeat = interaction.soft_repeat,
        on_repeat = interaction.on_repeat,
        style = style or control_style(theme, interaction.hover_foreground_color, color),
    })
    if interaction.tooltip or interaction.disabled_tooltip then
        return PlayerTooltip({
            child = button,
            text = interaction.tooltip,
            disabled_text = interaction.disabled_tooltip,
            enabled = enabled,
        })
    end
    return button
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
        local style = control_style(
            theme, hover_color or theme.window_control_color, theme.window_control_color)
        return icon_control(
            theme, actions, name, action_name, icon_name, item, theme.window_control_size,
            theme.window_control_color, nil, style)
    end
    return Stack({
        children = {
            Positioned({
                left = 10, top = 0, width = theme.window_control_width,
                height = theme.window_control_height,
                child = control('minimize', 'minimize', 'minimize', Color.hex('#53A4FC')),
            }),
            Positioned({
                left = 54, top = 0, width = theme.window_control_width,
                height = theme.window_control_height,
                child = control('maximize', 'maximize', 'toggle_maximized', Color.hex('#53A4FC')),
            }),
            Positioned({
                left = 98, top = 0, width = theme.window_control_width,
                height = theme.window_control_height,
                child = control('close', 'close', 'close', Color.hex('#E81123')),
            }),
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
    local buffered = buffered_progress(snapshot)
    local markers = theme.show_chapter_markers and chapter_markers(snapshot, duration) or {}
    local ranges = seek_ranges(snapshot, duration)
    for _, range in ipairs(sponsor_ranges(snapshot, duration)) do
        ranges[#ranges + 1] = range
    end
    local thumbfast_enabled = capability_available(snapshot, 'thumbfast')
        and actions:has('thumbfast_request')

    children[#children + 1] = positioned(
        layout_geometry.controller,
        panel(theme, theme.controller_color, theme.controller_border_color,
            theme.controller_blur_radius, false))
    if layout_geometry.visibility.persistent_progress then
        children[#children + 1] = positioned(layout_geometry.persistent_progress, ProgressBar({
            progress = progress,
            buffered = theme.persistent_buffer and buffered or 0,
            height = theme.persistent_progress_height,
            handle_size = 0,
            track_color = ColorTransparent,
            buffered_color = theme.seekbar_buffer_color,
            progress_color = theme.seekbar_progress_color,
            handle_color = theme.seekbar_progress_color,
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
        buffered = buffered,
        height = theme.progress_bar_height,
        track_color = theme.show_chapter_markers and theme.chapter_marker_style == 'gap'
            and theme.seekbar_track_color or ColorTransparent,
        buffered_color = theme.seekbar_buffer_color,
        progress_color = theme.seekbar_progress_color,
        handle_color = theme.seekbar_progress_color,
        hover_track_color = theme.seekbar_track_color,
        hover_buffered_color = theme.seekbar_buffer_color,
        hover_progress_color = theme.seekbar_progress_color,
        hover_handle_color = theme.seekbar_progress_color,
        hover_handle_size = theme.hover_handle_size,
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
        bounds_width = layout_geometry.seekbar:width(),
        expand = theme.seekbar_hit_expand,
        offset_x = 0,
        offset_y = -30,
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
            actions:thumbfast_request(
                duration * fraction,
                layout_geometry.seekbar.left + point.x,
                layout_geometry.seekbar.top + point.y)
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
        local title_child = Text(title, { style = title_style })
        if actions:has('show_stats') then
            title_child = GestureDetector(title_child, {
                on_tap = function()
                    actions:show_stats()
                end,
            })
        end
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
                child = GestureDetector(Text(chapter, { style = chapter_style }), {
                    on_enter = function() end,
                    on_leave = function() end,
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
            handle_size = 0,
            hover_handle_size = 0.8,
            hover_expand = theme.volume_hit_expand,
            track_color = ColorTransparent,
            progress_color = theme.volume_progress_color,
            buffered_color = ColorTransparent,
            handle_color = theme.volume_progress_color,
            hover_track_color = theme.volume_progress_color,
            hover_progress_color = theme.volume_progress_color,
            hover_handle_color = theme.volume_progress_color,
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
    end

    local function add_center(name, action_name, icon_name, icon_size, color, callback, interaction)
        local item_rect = layout_geometry.center[name]
        if item_rect then
            children[#children + 1] = positioned(item_rect, icon_control(
                theme, actions, name, action_name, icon_name, item_rect, icon_size, color,
                callback, nil, interaction))
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
                tooltip = 'Previous item',
                disabled_tooltip = 'No previous item',
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
                tooltip = 'Next item',
                disabled_tooltip = 'No next item',
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
            theme.middle_button_color, function() chapter_callback(-1) end, {
                enabled = has_chapters or theme.compact_mode,
                on_right_click = function() jump_seek(-theme.jump_more_amount) end,
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
                tooltip = 'Previous chapter',
                disabled_tooltip = 'No chapters',
            })
        add_center('chapter_next', nil, jump_icon('forward', theme.jump_amount), theme.middle_button_size,
            theme.middle_button_color, function() chapter_callback(1) end, {
                enabled = has_chapters or theme.compact_mode,
                on_right_click = function() jump_seek(theme.jump_more_amount) end,
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
                tooltip = 'Next chapter',
                disabled_tooltip = 'No chapters',
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
                on_right_click = function() jump_seek(-theme.jump_more_amount) end,
                on_shift_click = function() if actions:has('frame_back_step') then actions:frame_back_step() end end,
                soft_repeat = theme.jump_softrepeat,
                tooltip = string.format('Back %gs', theme.jump_amount),
                disabled_tooltip = 'Seek unavailable',
            })
        add_center('jump_forward', nil, jump_forward_icon, theme.middle_button_size,
            theme.middle_button_color, function()
                jump_seek(theme.jump_amount)
            end, {
                enabled = actions:has('seek'),
                on_right_click = function() jump_seek(theme.jump_more_amount) end,
                on_shift_click = function() if actions:has('frame_step') then actions:frame_step() end end,
                soft_repeat = theme.jump_softrepeat,
                tooltip = string.format('Forward %gs', theme.jump_amount),
                disabled_tooltip = 'Seek unavailable',
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
            tooltip = is_eof and 'Replay' or (is_paused and 'Play' or 'Pause'),
            disabled_tooltip = 'Playback unavailable',
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
                interaction and interaction.on_click or nil, nil, interaction))
        end
    end
    add_side('audio', nil, 'audio', {
        enabled = has_track_data('audio') and (actions:has('set_track') or actions:has('cycle_audio')),
        on_click = function() cycle_track('audio', 1) end,
        on_right_click = function() cycle_track('audio', -1) end,
        on_wheel = function(delta) cycle_track('audio', delta > 0 and 1 or -1) end,
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
        on_click = function() cycle_track('sub', 1) end,
        on_right_click = function() cycle_track('sub', -1) end,
        on_wheel = function(delta) cycle_track('sub', delta > 0 and 1 or -1) end,
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
        volume_icon = 'volume_mute'
    elseif volume >= 75 then
        volume_icon = 'volume_up'
    elseif volume <= 0 then
        volume_icon = 'volume_off'
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
        tooltip = snapshot and snapshot:get('mute') == true and 'Unmute' or 'Mute',
        disabled_tooltip = 'Volume unavailable',
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
                and 'fullscreen_exit' or 'fullscreen',
            tooltip = snapshot and snapshot:get('fullscreen') == true
                and 'Exit fullscreen' or 'Fullscreen' },
        { name = 'loop', action = 'toggle_loop',
            icon = snapshot and snapshot:get('loop_file') == true and 'repeat_on' or 'repeat',
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
                theme.side_button_size, theme.side_button_color, item.callback, nil, item))
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
            self.theme, self.actions, snapshot, self.title, layout_geometry)
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

M.PlayerLayout = PlayerLayout
M.PlayerDescriptionLayer = PlayerDescriptionLayer

return M
