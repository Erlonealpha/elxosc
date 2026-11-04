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
local transform_widgets = require 'widget.widgets.transform_box'

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
local TransformBox = transform_widgets.TransformBox
local Size = geometry.Size
local RenderTransformBox = require('render.transform_box').RenderTransformBox
local RenderDecoratedBox = require('render.decorated_box').RenderDecoratedBox
local RenderGesture = require('render.gesture').RenderGesture
local RenderText = require('render.text').RenderText

---@class _ButtonBaseOptions : _ButtonStyleOptions
---@field key any?
---@field label string|number?
---@field child Widget?
---@field on_click fun()?
---@field on_right_click fun()?
---@field on_shift_click fun(button: PointerButton, event: PointerEvent?)?
---@field on_wheel fun(delta: number)?
---@field soft_repeat boolean?
---@field on_repeat fun()?
---@field enabled boolean?
---@field style ButtonStyle?
---@field font_size number?
---@field padding EdgeInsets?

---@class ButtonState : State
---@field widget ButtonBase
---@field hovered boolean
---@field pressed boolean
---@field _repeat_ticker Ticker?
---@field _repeat_ticks integer
---@field _down_action_fired boolean
---@overload fun(): self
local ButtonState = std.class.new('ButtonState', { State })
function ButtonState:init_state()
    self.hovered = false
    self.pressed = false
    self._repeat_ticker = nil
    self._repeat_ticks = 0
    self._down_action_fired = false
end

function ButtonState:_stop_repeat()
    if self._repeat_ticker then
        self._repeat_ticker:stop()
        self._repeat_ticker = nil
    end
    self._repeat_ticks = 0
end

function ButtonState:_start_repeat()
    self:_stop_repeat()
    local context = self.context
    local owner = context and context.owner
    if not self.widget.soft_repeat or not owner or not owner.scheduler then
        return
    end
    self._repeat_ticker = self:create_ticker(function()
        if not self.pressed or not self:is_mounted() then
            self:_stop_repeat()
            return
        end
        self._repeat_ticks = self._repeat_ticks + 1
        if self._repeat_ticks >= 15 and self._repeat_ticks % 5 == 0 then
            local widget = self.widget
            local callback = widget.on_repeat or widget.on_click
            if callback then
                callback()
            end
        end
    end)
    self._repeat_ticker:start()
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

---@param state "normal"|"hover"|"pressed"|"disabled"
---@return Decoration
function ButtonState:_decoration(state)
    local style = self.widget.style
    local shadow_color = style:shadow_for(style.elevation)
    local shadow_offset = style.elevation > 0 and Offset(0, style.elevation) or nil
    local shadow_radius = style.elevation
    return Decoration({
        color = style:background_for(state),
        radius = style.radius,
        border_width = style.border_width,
        border_color = style.border_color,
        shadow_color = shadow_color,
        shadow_offset = shadow_offset,
        shadow_radius = shadow_radius,
    })
end

---@param gesture RenderGesture
function ButtonState:_update_visual(gesture)
    local button = self.widget
    self.hovered = gesture.hovered
    self.pressed = gesture.pressed
    if not self.pressed then
        self:_stop_repeat()
    end
    local state = self:visual_state()
    local children = gesture:children()
    local transform = children[1]
    if not std.isinstance(transform, RenderTransformBox) then
        return
    end
    local factor = state == 'hover' and button.style.hover_scale or 1
    transform:set_scale(Size(factor, factor))
    local visual_children = transform:children()
    local decorated = visual_children[1]
    if std.isinstance(decorated, RenderDecoratedBox) then
        decorated:set_decoration(self:_decoration(state))
    end
    local foreground = button.style:foreground_for(state)
    local shadow_color = state == 'hover' and button.style.hover_shadow_color or nil
    local shadow_radius = shadow_color and button.style.hover_shadow_radius or nil
    local function update_text(node)
        if std.isinstance(node, RenderText) then
            node:set_color_override(foreground)
            node:set_glow_override(shadow_color, shadow_radius)
        end
        for _, child in ipairs(node:children()) do
            update_text(child)
        end
    end
    update_text(transform)
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
    local decoration = self:_decoration(state)
    local body = Container({
        child = child,
        padding = style.padding or EdgeInsets.symmetric(12, 6),
        decoration = decoration,
    })
    if not button.enabled
        or (not button.on_click and not button.on_right_click
            and not button.on_shift_click and not button.on_wheel) then
        return GestureDetector(TransformBox(body), {
            on_state_change = function(gesture)
                self:_update_visual(gesture)
            end,
        })
    end
    local factor = state == 'hover' and style.hover_scale or 1
    local visual = TransformBox(body, { scale = Size(factor, factor) })
    return GestureDetector(visual, {
        initial_hovered = self.hovered,
        initial_pressed = self.pressed,
        on_enter = function() end,
        on_leave = function() end,
        on_state_change = function(gesture)
            self:_update_visual(gesture)
        end,
        on_button_down = function(_, button_name, _, event)
            self._down_action_fired = false
            if button_name == 'left' and not (event and event.modifiers and event.modifiers.shift) then
                if button.soft_repeat and button.on_click then
                    button.on_click()
                    self._down_action_fired = true
                end
                self:_start_repeat()
            end
            if button_name ~= nil and event and event.modifiers and event.modifiers.shift
                and button.on_shift_click then
                button.on_shift_click(button_name, event)
                return true
            end
            if button_name == 'middle' and button.on_shift_click then
                button.on_shift_click('left', event)
                return true
            end
            if button_name == 'right' and button.on_right_click then
                button.on_right_click()
                return true
            end
            return false
        end,
        on_wheel = button.on_wheel and function(_, delta)
            button.on_wheel(delta)
            return true
        end or nil,
        on_tap = function()
            if self._down_action_fired then
                self._down_action_fired = false
            elseif button.on_click then
                button.on_click()
            end
        end,
    })
end

---@class ButtonBase : StatefulWidget
---@field label string|number?
---@field child Widget?
---@field on_click fun()?
---@field on_right_click fun()?
---@field on_shift_click fun(button: PointerButton, event: PointerEvent?)?
---@field on_wheel fun(delta: number)?
---@field soft_repeat boolean
---@field on_repeat fun()?
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
    self.on_right_click = options.on_right_click
    self.on_shift_click = options.on_shift_click
    self.on_wheel = options.on_wheel
    self.soft_repeat = options.soft_repeat == true
    self.on_repeat = options.on_repeat
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
