-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Icon widget: a single glyph from the bundled icon font.
--
-- Like Flutter's `Icon`, this is a nominal square box around `Text`: the
-- glyph is chosen by its ligature name (`FluentIconNames`, generated from the
-- bundled Material Symbols Rounded font) and drawn with that font family. The
-- family is only an intent here -- the host resolves it against the fonts it
-- loads, so this module stays backend agnostic.

---@namespace elxosc
---@using elxosc

local std = require 'elxlibs.std'
local color = require 'src.foundation.color'
local geometry = require 'src.foundation.geometry'
local text_style = require 'src.text.text_style'
local anchor_mod = require 'src.foundation.anchor'
local text_paint_mod = require 'src.painting.text_paint'
local text_widgets = require 'src.widgets.text'
local align_mod = require 'src.widgets.align'
local sized_box_mod = require 'src.widgets.sized_box'
local symbols_mod = require 'fonts.material_symbols'
local widget_mod = require 'src.widgets.framework'

local Color = color.Color
local Offset = geometry.Offset
local TextStyle = text_style.TextStyle
local Anchor = anchor_mod.Anchor
local TextPaint = text_paint_mod.TextPaint
local Text = text_widgets.Text
local Align = align_mod.Align
local SizedBox = sized_box_mod.SizedBox
local MaterialSymbols = symbols_mod.MaterialSymbols
local StatelessWidget = widget_mod.StatelessWidget
local raise = std.raise

-- Matches `FluentIconFontName` in lib/fonts/fluent_icon_names.lua.
local DEFAULT_FONT_FAMILY = MaterialSymbols.font_family

-- Flutter's `kDefaultIconSize`.
local DEFAULT_SIZE = 24

---@class _IconOptions : MaterialSymbolsVariations
---@field size number?
---@field color Color?
---@field font_family string?
---@field text_layout TextLayout?
---@field optical_offset Offset? visual correction applied to the center target
---@field fill number? Material Symbols FILL axis, 0..1
---@field weight number? Material Symbols wght axis, 100..700
---@field grade number? Material Symbols GRAD axis, -25..200
---@field optical_size number? Material Symbols opsz axis, 20..48
---@field key any?

---@class Icon : StatelessWidget, MaterialSymbolsVariations
---@field name string
---@field size number
---@field color Color
---@field font_family string
---@field text_layout TextLayout?
---@field optical_offset Offset
---@field fill number
---@field weight number
---@field grade number
---@field optical_size number
---@overload fun(name: string, options: _IconOptions?): self
local Icon = std.class.new('Icon', StatelessWidget)

---@param name string
---@param options _IconOptions?
function Icon:__init(name, options)
    options = options or {}
    self.key = options.key
    self.name = name
    self.size = options.size or DEFAULT_SIZE
    self.color = options.color or Color.argb(0xFFFFFFFF)
    self.font_family = options.font_family or DEFAULT_FONT_FAMILY
    self.text_layout = options.text_layout
    local variations = MaterialSymbols.normalize(
        self.font_family == DEFAULT_FONT_FAMILY and options or nil)
    self.fill = variations.fill
    self.weight = variations.weight
    self.grade = variations.grade
    self.optical_size = variations.optical_size
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
            extra = self.font_family == DEFAULT_FONT_FAMILY and MaterialSymbols.text_extra(self) or nil,
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

---@class mod.src.widgets.icon
local M = { Icon = Icon }

return M
