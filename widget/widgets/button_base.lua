-- Shared implementation for all button variants.
---@diagnostic disable: undefined-field, inject-field, generic-constraint-mismatch, param-type-mismatch

local std = require 'elxlibs.std'
local geometry = require 'foundation.geometry'
local color_mod = require 'foundation.color'
local text_style = require 'text.text_style'
local text_widgets = require 'widget.widgets.text'
local gesture_widgets = require 'widget.widgets.gesture_detector'
local container_mod = require 'widget.widgets.container'
local decorated_mod = require 'widget.widgets.decorated_box'
local widget_mod = require 'widget.widget'
local state_mod = require 'widget.state'
local style_mod = require 'widget.widgets.button_style'

local EdgeInsets, Offset = geometry.EdgeInsets, geometry.Offset
local Color = color_mod.Color
local TextStyle, Text = text_style.TextStyle, text_widgets.Text
local GestureDetector = gesture_widgets.GestureDetector
local Container = container_mod.Container
local Decoration = decorated_mod.Decoration
local StatefulWidget = widget_mod.StatefulWidget
local State = state_mod.State
local ButtonStyle = style_mod.ButtonStyle

local ButtonState = std.class.new('ButtonState', { State })
function ButtonState:init_state()
    self.hovered, self.pressed = false, false
end
function ButtonState:visual_state()
    if not self.widget.enabled then return 'disabled' end
    if self.pressed then return 'pressed' end
    if self.hovered then return 'hover' end
    return 'normal'
end
function ButtonState:build()
    local button = self.widget
    local style = button.style
    local state = self:visual_state()
    local child = button.child
    if not child then
        child = Text(button.label or '', { style = TextStyle(button.font_size or 16, {
            color = style.foreground_color,
        }) })
    end
    local decoration = Decoration({
        color = style:background_for(state),
        radius = style.radius,
        border_width = style.border_width,
        border_color = style.border_color,
        shadow_color = style:shadow_for(style.elevation),
        shadow_offset = style.elevation > 0 and Offset(0, style.elevation) or nil,
        shadow_radius = style.elevation,
    })
    local body = Container({
        child = child,
        padding = style.padding or EdgeInsets.symmetric(12, 6),
        decoration = decoration,
    })
    if not button.enabled or not button.on_click then return body end
    return GestureDetector(body, {
        on_down = function() self:set_state(function() self.pressed = true end) end,
        on_up = function() self:set_state(function() self.pressed = false end) end,
        on_enter = function() self:set_state(function() self.hovered = true end) end,
        on_leave = function() self:set_state(function() self.hovered, self.pressed = false, false end) end,
        on_tap = function()
            if button.on_click then button.on_click() end
        end,
    })
end

---@class ButtonBase : StatefulWidget
---@field label string|number?
---@field child Widget?
---@field on_click fun()?
---@field enabled boolean
---@field style ButtonStyle
local ButtonBase = std.class.new('ButtonBase', { StatefulWidget })
function ButtonBase:__init(options)
    options = options or {}
    self.key, self.id = options.key, options.id
    self.label, self.child, self.on_click = options.label, options.child, options.on_click
    self.enabled = options.enabled ~= false
    self.style = options.style or ButtonStyle()
    self.font_size = options.font_size
end
function ButtonBase:create_state() return ButtonState() end
function ButtonBase:child_widgets() return self.child and { self.child } or {} end
function ButtonBase:bind_target() return 'child' end

return { ButtonBase = ButtonBase, ButtonStyle = ButtonStyle }
