-- Clickable text with paint-only foreground and glow feedback.

local std = require 'elxlibs.std'
local geometry = require 'foundation.geometry'
local text_mod = require 'widget.widgets.text'
local button_mod = require 'widget.widgets.button_base'
local container_mod = require 'widget.widgets.container'
local widget_mod = require 'widget.widget'
local text_style_mod = require 'text.text_style'

local Offset = geometry.Offset
local EdgeInsets = geometry.EdgeInsets
local Container = container_mod.Container
local Text = text_mod.Text
local ButtonBase = button_mod.ButtonBase
local ButtonStyle = button_mod.ButtonStyle
local StatelessWidget = widget_mod.StatelessWidget

local color_mod = require 'foundation.color'
local Color = color_mod.Color
local ColorTransparent = Color.rgba255(0, 0, 0, 0)

---@class elxosc.widget.widgets.hover_text
local M = {}
local default_style = text_style_mod.TextStyle({ wrap = false })

local function hover_text_button(child, foreground_color, hover_color, pressed_color,
    glow_color, glow_radius, callback)
    if callback == nil then
        return child
    end
    return ButtonBase({
        child = child,
        on_click = callback,
        style = ButtonStyle({
            background_color = ColorTransparent,
            hover_color = ColorTransparent,
            pressed_color = ColorTransparent,
            foreground_color = foreground_color,
            hover_foreground_color = hover_color,
            pressed_foreground_color = pressed_color,
            padding = EdgeInsets.zero(),
            radius = 0,
            hover_scale = 1,
            hover_shadow_color = glow_color,
            hover_shadow_radius = glow_radius,
        }),
    })
end

---@class _HoverTextOptions
---@field text string?
---@field style TextStyle?
---@field alignment Offset?
---@field hover_color Color?
---@field hover_shadow_color Color?
---@field hover_shadow_radius number?
---@field on_tap fun()?
---@field key any?

---@class HoverText : StatelessWidget
---@field text string
---@field style TextStyle
---@field alignment Offset
---@field hover_color Color
---@field hover_shadow_color Color?
---@field hover_shadow_radius number
---@field on_tap fun()?
---@overload fun(options?: _HoverTextOptions): self
local HoverText = std.class.new('HoverText', StatelessWidget)

function HoverText:__init(options)
    options = options or {}
    self.key = options.key
    self.text = options.text or ''
    self.style = options.style or default_style
    self.alignment = options.alignment or Offset(0.5, 0.5)
    self.hover_color = options.hover_color or self.style.color
    self.hover_shadow_color = options.hover_shadow_color
    self.hover_shadow_radius = options.hover_shadow_radius or 0
    self.on_tap = options.on_tap
end

function HoverText:build()
    return hover_text_button(Container({
        alignment = self.alignment,
        child = Text(self.text, { style = self.style }),
    }), self.style.color, self.hover_color, self.hover_color,
    self.hover_shadow_color, self.hover_shadow_radius, self.on_tap)
end

M.HoverText = HoverText

return M
