-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Icon widget: a single glyph from the bundled icon font.
--
-- Like Flutter's `Icon`, this is a thin `StatelessWidget` over `Text`: the
-- glyph is chosen by its ligature name (`FluentIconNames`, generated from the
-- bundled Material Symbols Rounded font) and drawn with that font family. The
-- family is only an intent here -- the host resolves it against the fonts it
-- loads, so this module stays backend agnostic.

local std = require 'elxlibs.std'
local color = require 'foundation.color'
local text_style = require 'text.text_style'
local text_widgets = require 'widget.widgets.text'
local widget_mod = require 'widget.widget'

local Color = color.Color
local TextStyle = text_style.TextStyle
local Text = text_widgets.Text
local StatelessWidget = widget_mod.StatelessWidget

-- Matches `FluentIconFontName` in fonts/fluent_icon_names.lua.
local DEFAULT_FONT_FAMILY = 'Material Symbols Rounded'

-- Flutter's `kDefaultIconSize`.
local DEFAULT_SIZE = 24

---@class _IconOptions
---@field size number?
---@field color Color?
---@field font_family FluentIconFontName?
---@field text_layout TextLayout?
---@field key any?
---@field id string?

---@class Icon : StatelessWidget
---@field name string
---@field size number
---@field color Color
---@field font_family FluentIconFontName
---@field text_layout TextLayout?
---@overload fun(name: FluentIconNames, options: _IconOptions?): Icon
local Icon = std.class.new('Icon', { StatelessWidget })

---@param name FluentIconNames
---@param options _IconOptions?
function Icon:__init(name, options)
    options = options or {}
    self.key = options.key
    self.id = options.id
    self.name = name
    self.size = options.size or DEFAULT_SIZE
    self.color = options.color or Color.argb(0xFFFFFFFF)
    self.font_family = options.font_family or DEFAULT_FONT_FAMILY
    self.text_layout = options.text_layout
end

---@return Widget
function Icon:build()
    return Text(self.name, {
        style = TextStyle(self.size, {
            color = self.color,
            font_family = self.font_family,
            wrap = false,
        }),
        text_layout = self.text_layout,
    })
end

return { Icon = Icon }
