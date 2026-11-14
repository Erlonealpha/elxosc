-- Clickable text with paint-only foreground and glow feedback.

---@namespace elxosc
---@using elxosc

local std = require 'elxlibs.std'
local geometry = require 'src.foundation.geometry'
local text_mod = require 'src.widgets.text'
local gesture_mod = require 'src.widgets.gesture_detector'
local container_mod = require 'src.widgets.container'
local widget_mod = require 'src.widgets.framework'
local text_style_mod = require 'src.text.text_style'

local Offset = geometry.Offset
local Container = container_mod.Container
local Text = text_mod.Text
local GestureDetector = gesture_mod.GestureDetector
local StatelessWidget = widget_mod.StatelessWidget

local RenderText = require('src.render.text').RenderText

---@class mod.src.widgets.hover_text
local M = {}
local default_style = text_style_mod.TextStyle({ wrap = false })

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

---@param gesture RenderGesture
function HoverText:_update_visual(gesture)
    local foreground = (gesture.hovered or gesture.pressed) and self.hover_color or self.style.color
    local glow = gesture.hovered and not gesture.pressed and self.hover_shadow_color or nil
    local function update_text(node)
        if std.isinstance(node, RenderText) then
            node:set_color_override(foreground)
            node:set_glow_override(glow, glow and self.hover_shadow_radius or nil)
        end
        for _, child in ipairs(node:children()) do
            update_text(child)
        end
    end
    update_text(gesture)
end

function HoverText:build()
    local body = Container({
        alignment = self.alignment,
        child = Text(self.text, { style = self.style }),
    })
    if self.on_tap == nil then
        return body
    end
    return GestureDetector(body, {
        on_enter = function() end,
        on_leave = function() end,
        on_state_change = function(gesture)
            self:_update_visual(gesture)
        end,
        on_tap = function()
            self.on_tap()
        end,
    })
end

M.HoverText = HoverText

return M
