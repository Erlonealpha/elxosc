-- Single-tree description preview, panel and keyboard lifecycle.

local std = require 'elxlibs.std'
local geometry = require 'foundation.geometry'
local text_style_mod = require 'text.text_style'
local actions_mod = require 'widget.actions'
local basic_widgets = require 'widget.widgets.basic'
local layout_widgets = require 'widget.widgets.layout'
local widget_mod = require 'widget.widget'
local icon_map = require 'widget.player.icon_map'

local Offset = geometry.Offset
local EdgeInsets = geometry.EdgeInsets
local TextStyle = text_style_mod.TextStyle
local HostActions = actions_mod.HostActions
local Container = layout_widgets.Container
local Positioned = layout_widgets.Positioned
local Stack = layout_widgets.Stack
local SizedBox = layout_widgets.SizedBox
local Column = layout_widgets.Column
local OffsetBox = layout_widgets.OffsetBox
local Text = basic_widgets.Text
local GestureDetector = basic_widgets.GestureDetector
local Icon = icon_map.icon
local StatefulWidget = widget_mod.StatefulWidget
local widget_state_mod = require 'widget.state'
local State = widget_state_mod.State

local max = math.max
local min = math.min
local color_mod = require 'foundation.color'
local Color = color_mod.Color
local ColorBlack = Color.rgba255(0, 0, 0, 255)

local text_controls_mod = require 'widget.player.text_controls'
local PlayerHoverText = text_controls_mod.PlayerHoverText

---@class elxosc.widget.player.description
local M = {}

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
local PlayerDescriptionLayer = std.class.new('PlayerDescriptionLayer', StatefulWidget)

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
local PlayerDescriptionLayerState = std.class.new('PlayerDescriptionLayerState', State)

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

---@return boolean
function PlayerDescriptionLayerState:keep_auto_hide_visible()
    return self.open
end

function PlayerDescriptionLayerState:build()
    local widget = self.widget --[[@as PlayerDescriptionLayer]]
    local bounds = widget.bounds
    if not self.open then
        local alignment = bounds.left < widget.viewport_width / 2 and Offset(0, 0.5) or Offset(1, 0.5)
        return Stack({
            children = {
                Positioned({
                    left = bounds.left,
                    top = bounds.top,
                    width = bounds:width(),
                    height = bounds:height(),
                    child = PlayerHoverText({
                        text = widget.preview,
                        style = TextStyle({
                            font_size = widget.theme.description_font_size,
                            color = widget.theme.description_color,
                            blur_radius = 1,
                            outline_width = 0.5,
                            outline_color = ColorBlack,
                            wrap = false,
                        }),
                        alignment = alignment,
                        hover_color = widget.theme.hover_color,
                        hover_shadow_color = widget.theme.hover_color,
                        hover_shadow_radius = widget.theme.button_glow_amount,
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

M.PlayerDescriptionLayer = PlayerDescriptionLayer

return M
