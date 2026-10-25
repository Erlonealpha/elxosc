-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Icon widget: a single glyph from the bundled icon font.
--
-- Like Flutter's `Icon`, this is a nominal square box around `Text`: the
-- glyph is chosen by its ligature name (`FluentIconNames`, generated from the
-- bundled Material Symbols Rounded font) and drawn with that font family. The
-- family is only an intent here -- the host resolves it against the fonts it
-- loads, so this module stays backend agnostic.

local std = require 'elxlibs.std'
local color = require 'foundation.color'
local geometry = require 'foundation.geometry'
local text_style = require 'text.text_style'
local anchor_mod = require 'foundation.anchor'
local text_paint_mod = require 'painting.text_paint'
local text_widgets = require 'widget.widgets.text'
local layout_widgets = require 'widget.widgets.layout'
local widget_mod = require 'widget.widget'

local Color = color.Color
local Offset = geometry.Offset
local TextStyle = text_style.TextStyle
local Anchor = anchor_mod.Anchor
local TextPaint = text_paint_mod.TextPaint
local Text = text_widgets.Text
local Align = layout_widgets.Align
local SizedBox = layout_widgets.SizedBox
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
---@field optical_offset Offset? visual correction applied to the center target
---@field key any?

---@class Icon : StatelessWidget
---@field name FluentIconNames
---@field size number
---@field color Color
---@field font_family FluentIconFontName
---@field text_layout TextLayout?
---@field optical_offset Offset
---@overload fun(name: FluentIconNames, options: _IconOptions?): self
local Icon = std.class.new('Icon', { StatelessWidget })

---@param name FluentIconNames
---@param options _IconOptions?
function Icon:__init(name, options)
    options = options or {}
    self.key = options.key
    self.name = name
    self.size = options.size or DEFAULT_SIZE
    self.color = options.color or Color.argb(0xFFFFFFFF)
    self.font_family = options.font_family or DEFAULT_FONT_FAMILY
    self.text_layout = options.text_layout
    local optical_offset = options.optical_offset
    self.optical_offset = optical_offset == nil and Offset.zero()
        or TextPaint({ offset = optical_offset }).offset
end

---@return Widget
function Icon:build()
    ---@type _TextPaintOptions
    local paint_options = {
        anchor = Anchor.CENTER,
        offset = self.optical_offset,
    }
    local glyph = Text(self.name, {
        style = TextStyle({
            font_size = self.size,
            color = self.color,
            font_family = self.font_family,
            wrap = false,
        }),
        text_layout = self.text_layout,
        text_paint = TextPaint(paint_options),
    })
    return SizedBox({
        width = self.size,
        height = self.size,
        child = Align(glyph, { alignment = Offset(0.5, 0.5) }),
    })
end

return { Icon = Icon }
