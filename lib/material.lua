-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Styled construction surface, including every basic widget member.
---@namespace elxosc
---@using elxosc

local exports = require('export').new()
local geometry = require 'src.foundation.geometry'
local color = require 'src.foundation.color'
local paint = require 'src.painting.paint'
local text_style = require 'src.text.text_style'
local transform = require 'src.foundation.transform'
local anchor = require 'src.foundation.anchor'
local text_paint = require 'src.painting.text_paint'

local export = exports.export

export('material', require 'widgets')
export('material', require 'src.material.button', true)
export('material', require 'src.material.button_base', true)
export('material', require 'src.material.button_style', true)
export('material', require 'src.material.elevated_button', true)
export('material', require 'src.material.icon_button', true)
export('material', require 'src.material.icons', true)
export('material', require 'src.material.outlined_button', true)
export('material', require 'src.material.progress_indicator', true).show('LinearProgressIndicator')
export('material', require 'src.material.slider', true).show('Slider')
export('material', require 'src.material.text_button', true)
export('material', require 'src.material.theme', true)

---@class material.ValueExports
local values = {
    Offset = geometry.Offset,
    Point = geometry.Point,
    Size = geometry.Size,
    Rect = geometry.Rect,
    EdgeInsets = geometry.EdgeInsets,
    Color = color.Color,
    Paint = paint.Paint,
    TextStyle = text_style.TextStyle,
    Matrix2D = transform.Matrix2D,
    Anchor = anchor.Anchor,
    TextPaint = text_paint.TextPaint
}
export('material', values, true)

---@class mod.material:
--- mod.widgets,
--- material.ValueExports,
--- mod.src.material.button,
--- mod.src.material.button_base,
--- mod.src.material.button_style,
--- mod.src.material.elevated_button,
--- mod.src.material.icon_button,
--- mod.src.material.icons,
--- mod.src.material.outlined_button,
--- mod.src.material.text_button,
--- mod.src.material.theme
---@field Slider                  material.Slider
---@field LinearProgressIndicator material.LinearProgressIndicator
local M = exports.get('material')

return M
