-- Shared implementation for all button variants.

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

local EdgeInsets = geometry.EdgeInsets
local Offset = geometry.Offset
local TextStyle = text_style.TextStyle
local Text = text_widgets.Text
local GestureDetector = gesture_widgets.GestureDetector
local Container = container_mod.Container
local Decoration = decorated_mod.Decoration
local StatefulWidget = widget_mod.StatefulWidget
local State = state_mod.State
local ButtonStyle = style_mod.ButtonStyle

---@class _ButtonBaseOptions : _ButtonStyleOptions
---@field key any?
---@field label string|number?
---@field child Widget?
---@field on_click fun()?
---@field enabled boolean?
---@field style ButtonStyle?
---@field font_size number?
---@field padding EdgeInsets?

---@class ButtonState : State
---@field widget ButtonBase
---@field hovered boolean
---@field pressed boolean
---@overload fun(): self
local ButtonState = std.class.new('ButtonState', { State })
function ButtonState:init_state()
    self.hovered = false
    self.pressed = false
end
---@return "normal"|"hover"|"pressed"|"disabled"
function ButtonState:visual_state()
    if not self.widget.enabled then
        return 'disabled'
    end
    if self.pressed then
        return 'pressed'
    end
    if self.hovered then
        return 'hover'
    end
    return 'normal'
end
---@return Widget
function ButtonState:build()
    local button = self.widget
    local style = button.style
    local state = self:visual_state()
    local child = button.child
    if not child then
        child = Text(button.label or '', {
            style = TextStyle({
                font_size = button.font_size or 16,
                color = style.foreground_color,
            }),
        })
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
    if not button.enabled or not button.on_click then
        return body
    end
    return GestureDetector(body, {
        on_down = function()
            self:set_state(function()
                self.pressed = true
            end)
        end,
        on_up = function()
            self:set_state(function()
                self.pressed = false
            end)
        end,
        on_enter = function()
            self:set_state(function()
                self.hovered = true
            end)
        end,
        on_leave = function()
            self:set_state(function()
                self.hovered = false
                self.pressed = false
            end)
        end,
        on_tap = function()
            if button.on_click then
                button.on_click()
            end
        end,
    })
end

---@class ButtonBase : StatefulWidget
---@field label string|number?
---@field child Widget?
---@field on_click fun()?
---@field enabled boolean
---@field style ButtonStyle
---@field font_size number?
---@overload fun(options: _ButtonBaseOptions?): self
local ButtonBase = std.class.new('ButtonBase', { StatefulWidget })
---@param options _ButtonBaseOptions?
function ButtonBase:__init(options)
    options = options or {}
    self.key = options.key
    self.label = options.label
    self.child = options.child
    self.on_click = options.on_click
    self.enabled = options.enabled ~= false
    self.style = options.style or ButtonStyle()
    self.font_size = options.font_size
end

---@generic T: table
---@param options T
---@return T
local function copy_options(options)
    local copy = {}
    for key, value in pairs(options) do
        copy[key] = value
    end
    return copy
end
---@return ButtonState
function ButtonBase:create_state()
    return ButtonState()
end

---@return Widget[]
function ButtonBase:child_widgets()
    if self.child then
        return { self.child }
    end
    return {}
end

return { ButtonBase = ButtonBase, ButtonStyle = ButtonStyle, copy_options = copy_options }
