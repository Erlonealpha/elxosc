-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

local geometry = require 'src.foundation.geometry'
local color = require 'src.foundation.color'
local paint = require 'src.painting.paint'
local text_style = require 'src.text.text_style'
local transform = require 'src.foundation.transform'
local anchor = require 'src.foundation.anchor'
local text_paint = require 'src.painting.text_paint'

--- Framework construction surface; host owns the default Define builtins.
local widgets = require 'widgets'
local theme = require 'src.material.theme'
local button = require 'src.material.button'
local button_base = require 'src.material.button_base'
local button_style = require 'src.material.button_style'
local elevated_button = require 'src.material.elevated_button'
local outlined_button = require 'src.material.outlined_button'
local text_button = require 'src.material.text_button'
local icon_button = require 'src.material.icon_button'
local slider = require 'src.material.slider'
local progress_indicator = require 'src.material.progress_indicator'
local icons = require 'src.material.icons'

---@class elxosc.mod.material : elxosc.mod.widgets
local M = {
    Theme = theme.Theme,
    ThemeData = theme.ThemeData,
    Button = button.Button,
    ButtonBase = button_base.ButtonBase,
    ButtonStyle = button_style.ButtonStyle,
    ElevatedButton = elevated_button.ElevatedButton,
    OutlinedButton = outlined_button.OutlinedButton,
    TextButton = text_button.TextButton,
    IconButton = icon_button.IconButton,
    LinearProgressIndicator = progress_indicator.LinearProgressIndicator,
    Slider = slider.Slider,
    MaterialSymbols = icons.MaterialSymbols,
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
    TextPaint = text_paint.TextPaint,
}

for name, value in pairs(widgets) do
    if M[name] == nil then
        M[name] = value
    end
end

return M
