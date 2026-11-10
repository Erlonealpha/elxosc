-- Player styling, background edges and individual control composition.

local geometry = require 'foundation.geometry'
local text_style_mod = require 'text.text_style'
local basic_widgets = require 'widget.widgets.basic'
local layout_widgets = require 'widget.widgets.layout'
local icon_map = require 'widget.player.icon_map'
local tooltip_mod = require 'widget.player.tooltip'

local Rect = geometry.Rect
local Offset = geometry.Offset
local EdgeInsets = geometry.EdgeInsets
local TextStyle = text_style_mod.TextStyle
local Container = layout_widgets.Container
local Positioned = layout_widgets.Positioned
local Stack = layout_widgets.Stack
local Column = layout_widgets.Column
local Text = basic_widgets.Text
local IconButton = basic_widgets.IconButton
local CustomPaint = basic_widgets.CustomPaint
local ButtonStyle = basic_widgets.ButtonStyle
local Icon = icon_map.icon
local PlayerTooltip = tooltip_mod.PlayerTooltip

local max = math.max
local color_mod = require 'foundation.color'
local Color = color_mod.Color
local painting_paint_mod = require 'painting.paint'
local Paint = painting_paint_mod.Paint
local PaintStyle = painting_paint_mod.Style
local ColorTransparent = Color.rgba255(0, 0, 0, 0)
local ColorBlack = Color.rgba255(0, 0, 0, 255)
local text_controls_mod = require 'widget.player.text_controls'
local PlayerHoverText = text_controls_mod.PlayerHoverText

---@class elxosc.widget.player.visuals
local M = {}

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
            local border_width = top and theme.window_border_width or theme.controller_border_width
            -- Put the source outside the viewport, as ModernX does. Extend it
            -- horizontally so blurred corners cannot leave seams at the edges.
            local y = top and offset.y - 71 or offset.y + size.height
            local edge = Rect.from_ltwh(offset.x - border_width, y,
                size.width + border_width * 2, 1)
            local fill = Paint(color)
            fill.blur_radius = blur_radius
            canvas:draw_rect(edge, fill)
            local border = Paint(border_color, PaintStyle.STROKE,
                border_width)
            border.blur_radius = blur_radius
            canvas:draw_rect(edge, border)
        end,
    })
end

local function control_style(theme, hover_foreground_color, foreground_color)
    local foreground = foreground_color or theme.side_button_color
    return ButtonStyle({
        background_color = ColorTransparent,
        hover_color = ColorTransparent,
        pressed_color = ColorTransparent,
        disabled_color = ColorTransparent,
        foreground_color = foreground,
        hover_foreground_color = hover_foreground_color or theme.hover_color,
        pressed_foreground_color = theme.held_color,
        disabled_foreground_color = Color(foreground.r, foreground.g, foreground.b,
            foreground.a * 40 / 255),
        hover_shadow_color = hover_foreground_color or theme.hover_color,
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
            bounds_width = interaction.tooltip_bounds_width,
            bounds_height = interaction.tooltip_bounds_height,
            anchor_left = interaction.tooltip_anchor_left or item_rect.left,
            anchor_top = interaction.tooltip_anchor_top or item_rect.top,
            anchor_width = item_rect:width(),
            anchor_height = item_rect:height(),
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
---@param theme PlayerThemeData
---@param title string
---@return Widget
local function default_title_bar(theme, title)
    return Container({
        alignment = Offset(0, 0.5),
        child = PlayerHoverText({
            text = title,
            style = TextStyle({
                font_size = 19,
                color = theme.title_color,
                blur_radius = 1,
                outline_width = 0.5,
                outline_color = ColorBlack,
                wrap = false,
            }),
            alignment = Offset(0, 0.5),
            hover_color = theme.hover_color,
            hover_shadow_color = theme.hover_glow_color,
            hover_shadow_radius = theme.button_glow_amount,
        }),
    })
end

---@param theme PlayerThemeData
---@param actions HostActions
---@return Widget
local function default_window_controls(theme, actions, snapshot)
    local function control(name, icon_name, action_name, hover_color)
        local item = Rect.from_ltwh(0, 0, theme.window_control_width, theme.window_control_height)
        local style = control_style(
            theme, hover_color or theme.window_control_color, theme.window_control_color)
        style.hover_scale = 1
        style.hover_shadow_color = nil
        style.hover_shadow_radius = 0
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
                child = control('fullscreen',
                    snapshot and snapshot:get('fullscreen') == true
                        and 'fullscreen_exit' or 'fullscreen',
                    'toggle_fullscreen', Color.hex('#53A4FC')),
            }),
            Positioned({
                left = 98, top = 0, width = theme.window_control_width,
                height = theme.window_control_height,
                child = control('close', 'close', 'close', Color.hex('#E81123')),
            }),
        },
    })
end

M.idle_view = idle_view
M.text_style = text_style
M.panel = panel
M.control_style = control_style
M.icon_control = icon_control
M.positioned = positioned
M.default_title_bar = default_title_bar
M.default_window_controls = default_window_controls

return M
