-- Clickable text with paint-only foreground and glow feedback.

---@namespace elxosc
---@using elxosc

local std = require 'elxlibs.std'
local geometry = require 'src.foundation.geometry'
local text_mod = require 'src.widgets.text'
local gesture_mod = require 'src.widgets.gesture_detector'
local align_mod = require 'src.widgets.align'
local constraints_mod = require 'src.layout.constraints'
local constrained_mod = require 'src.widgets.constraints'
local widget_mod = require 'src.widgets.framework'
local text_style_mod = require 'src.text.text_style'
local render_text_mod = require 'src.render.text'

local RenderText = render_text_mod.RenderText
local ipairs = ipairs
local math = math
local type = type

local Offset = geometry.Offset
local Align = align_mod.Align
local Text = text_mod.Text
local GestureDetector = gesture_mod.GestureDetector
local StatelessWidget = widget_mod.StatelessWidget

---@class mod.src.widgets.hover_text
local M = {}
local default_style = text_style_mod.TextStyle({ wrap = false })

---@class _HoverTextOptions
---@field text                string?
---@field style               TextStyle?
---@field alignment           Offset?
---@field hover_color         Color?
---@field hover_shadow_color  Color?
---@field hover_shadow_radius number?
---@field on_tap              fun()?
---@field key                 any?
---@field min_width           number?    stable content reservation; constrained by parent

---@class HoverText: StatelessWidget
---@field text                string
---@field style               TextStyle
---@field alignment           Offset
---@field hover_color         Color
---@field hover_shadow_color  Color?
---@field hover_shadow_radius number
---@field on_tap              fun()?
---@field min_width           number
---@overload fun(options?: _HoverTextOptions): self
local HoverText = std.class.new('HoverText', StatelessWidget)

---@param options _HoverTextOptions?
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
    self.min_width = options.min_width or 0
    if type(self.min_width) ~= 'number' or self.min_width < 0
        or self.min_width ~= self.min_width or self.min_width == math.huge then
        std.raise(std.ValueError('HoverText.min_width must be finite and non-negative'))
    end
end

---@param gesture RenderGesture
function HoverText:_update_visual(gesture)
    local foreground = (gesture.hovered or gesture.pressed) and self.hover_color or self.style.color
    local glow = gesture.hovered and not gesture.pressed and self.hover_shadow_color or nil
    ---@param node RenderObject
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

---@return Widget?
function HoverText:build()
    local body = constrained_mod.ConstrainedBox({
        constraints = constraints_mod.Constraints(self.min_width),
        child = Align(Text(self.text, { style = self.style, clip = true }), {
            alignment = self.alignment,
            width_factor = 1,
            height_factor = 1
        })
    })
    if self.on_tap == nil then
        return Align(body, { alignment = self.alignment })
    end
    return Align(GestureDetector(body, {
            on_enter = function () end,
            on_leave = function () end,
            on_state_change = function (gesture)
                self:_update_visual(gesture)
            end,
            on_tap = function ()
                self.on_tap()
            end
        }), { alignment = self.alignment })
end

M.HoverText = HoverText

return M
