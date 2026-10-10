-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Compatibility aggregate for the original basic widget module.

local text_widgets = require 'widget.widgets.text'
local custom_paint_widgets = require 'widget.widgets.custom_paint'
local gesture_widgets = require 'widget.widgets.gesture_detector'
local button_widgets = require 'widget.widgets.button'
local button_base = require 'widget.widgets.button_base'
local elevated_widgets = require 'widget.widgets.elevated_button'
local outlined_widgets = require 'widget.widgets.outlined_button'
local text_button_widgets = require 'widget.widgets.text_button'
local icon_button_widgets = require 'widget.widgets.icon_button'

---@class elxwidgets_basic
local M = {
    Text = text_widgets.Text,
    CustomPaint = custom_paint_widgets.CustomPaint,
    GestureDetector = gesture_widgets.GestureDetector,
    Button = button_widgets.Button,
    ButtonBase = button_base.ButtonBase,
    ButtonStyle = button_base.ButtonStyle,
    ElevatedButton = elevated_widgets.ElevatedButton,
    OutlinedButton = outlined_widgets.OutlinedButton,
    TextButton = text_button_widgets.TextButton,
    IconButton = icon_button_widgets.IconButton,
}

return M
