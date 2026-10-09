-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Compatibility aggregate for the original basic widget module.

local text_widgets = require 'widget.widgets.text'
local custom_paint_widgets = require 'widget.widgets.custom_paint'
local gesture_widgets = require 'widget.widgets.gesture_detector'
local button_widgets = require 'widget.widgets.button'

---@class elxwidgets_basic
local M = {
    Text = text_widgets.Text,
    CustomPaint = custom_paint_widgets.CustomPaint,
    GestureDetector = gesture_widgets.GestureDetector,
    Button = button_widgets.Button,
}

return M
