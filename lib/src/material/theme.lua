-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Design colors and surface defaults above the generic widgets runtime.
--
-- These values are immutable descriptions.  Runtime changes replace the
-- inherited widget, which lets listening descendants rebuild through the
-- existing InheritedWidget dependency mechanism.

---@namespace elxosc
---@using elxosc
---@using elxosc.material

local std = require 'elxlibs.std'
local dataclass = require 'elxlibs.dataclass'
local color_mod = require 'src.foundation.color'
local text_style_mod = require 'src.text.text_style'
local widget_mod = require 'src.widgets.framework'

local math = math
local type = type

local raise = std.raise
local Color = color_mod.Color
local TextStyle = text_style_mod.TextStyle
local InheritedWidget = widget_mod.InheritedWidget

---@class mod.src.material.theme
local M = {}

---@param value number?
---@return boolean
local function is_finite(value)
    return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

---@param context Element
---@param name    string
local function require_context(context, name)
    if context == nil or type(context.depend_on_inherited_widget_of_exact_type) ~= 'function' then
        raise(std.TypeError(name .. ' lookup expects a BuildContext'))
    end
end

-- == Theme ==================================================================

---@class material._ThemeDataOptions
---@field scale            number?    positive finite uniform layout scale
---@field background_color Color?
---@field surface_color    Color?
---@field accent_color     Color?
---@field text_style       TextStyle?

---@class material.ThemeData: std.object
---@field scale            number
---@field background_color Color
---@field surface_color    Color
---@field accent_color     Color
---@field text_style       TextStyle
---@overload fun(options?: _ThemeDataOptions): self
local ThemeData = std.class.new('ThemeData')

---@param options _ThemeDataOptions?
function ThemeData:__init(options)
    options = options or {}
    if type(options) ~= 'table' then
        raise(std.TypeError('ThemeData expects an options table'))
    end
    local scale = options.scale == nil and 1 or options.scale
    if not is_finite(scale) or scale <= 0 then
        raise(std.ValueError('ThemeData.scale must be a positive finite number'))
    end
    self.scale = scale
    self.background_color = options.background_color or Color.rgba(0x10151DDD)
    self.surface_color = options.surface_color or Color.rgba(0x202832EE)
    self.accent_color = options.accent_color or Color.rgba(0x68A0FFFF)
    self.text_style = options.text_style or TextStyle({ font_size = 14 })
    if not dataclass.isinstance(self.background_color, Color) or not dataclass.isinstance(self.surface_color, Color)
        or not dataclass.isinstance(self.accent_color, Color) then
        raise(std.TypeError('ThemeData colors must be Color values'))
    end
    if not std.isinstance(self.text_style, TextStyle) then
        raise(std.TypeError('ThemeData.text_style must be a TextStyle'))
    end
end

---@class material._ThemeOptions
---@field data  ThemeData
---@field child Widget?
---@field key   any?

---@class material.Theme: InheritedWidget
---@field data  ThemeData
---@field child Widget?
---@overload fun(options: _ThemeOptions): self
local Theme = std.class.new('Theme', InheritedWidget)
local ThemeClass = Theme --[[@as std.class]]

---@param options _ThemeOptions
function Theme:__init(options)
    if type(options) ~= 'table' then
        raise(std.TypeError('Theme expects an options table'))
    end
    self.key = options.key
    self.data = options.data or ThemeData()
    self.child = options.child
    if not std.isinstance(self.data, ThemeData) then
        raise(std.TypeError('Theme.data must be a ThemeData'))
    end
end

---@param old_widget Theme
---@return boolean
function Theme:update_should_notify(old_widget)
    return self.data ~= old_widget.data
end

---@param context BuildContext
---@return Theme
function Theme.of(context)
    require_context(context, 'Theme')
    local value = context:depend_on_inherited_widget_of_exact_type(ThemeClass)
    if value == nil then
        raise(std.RuntimeError('no Theme ancestor was found'))
    end
    return value --[[@as Theme]]
end

---@param context BuildContext
---@return Theme?
function Theme.maybe_of(context)
    require_context(context, 'Theme')
    return context:depend_on_inherited_widget_of_exact_type(ThemeClass) --[[@as Theme?]]
end

M.ThemeData = ThemeData
M.Theme = Theme

return M
