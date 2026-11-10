-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

---@class elxosc.widget.widgets : elxosc.src.widget.widgets.align, elxosc.src.widget.widgets.basic, elxosc.src.widget.widgets.button, elxosc.src.widget.widgets.button_base, elxosc.src.widget.widgets.button_style, elxosc.src.widget.widgets.constraints, elxosc.src.widget.widgets.container, elxosc.src.widget.widgets.custom_paint, elxosc.src.widget.widgets.decorated_box, elxosc.src.widget.widgets.elevated_button, elxosc.src.widget.widgets.flex, elxosc.src.widget.widgets.gesture_detector, elxosc.src.widget.widgets.hover_text, elxosc.src.widget.widgets.icon, elxosc.src.widget.widgets.icon_button, elxosc.src.widget.widgets.layout, elxosc.src.widget.widgets.offset_box, elxosc.src.widget.widgets.outlined_button, elxosc.src.widget.widgets.overflow, elxosc.src.widget.widgets.padding, elxosc.src.widget.widgets.positioned, elxosc.src.widget.widgets.progress_indicator, elxosc.src.widget.widgets.sized_box, elxosc.src.widget.widgets.slider, elxosc.src.widget.widgets.stack, elxosc.src.widget.widgets.text, elxosc.src.widget.widgets.text_button, elxosc.src.widget.widgets.tooltip, elxosc.src.widget.widgets.transform_box
local M = {}

M.align = require 'src.widget.widgets.align'
M.basic = require 'src.widget.widgets.basic'
M.button = require 'src.widget.widgets.button'
M.button_base = require 'src.widget.widgets.button_base'
M.button_style = require 'src.widget.widgets.button_style'
M.constraints = require 'src.widget.widgets.constraints'
M.container = require 'src.widget.widgets.container'
M.custom_paint = require 'src.widget.widgets.custom_paint'
M.decorated_box = require 'src.widget.widgets.decorated_box'
M.elevated_button = require 'src.widget.widgets.elevated_button'
M.flex = require 'src.widget.widgets.flex'
M.gesture_detector = require 'src.widget.widgets.gesture_detector'
M.hover_text = require 'src.widget.widgets.hover_text'
M.icon = require 'src.widget.widgets.icon'
M.icon_button = require 'src.widget.widgets.icon_button'
M.layout = require 'src.widget.widgets.layout'
M.offset_box = require 'src.widget.widgets.offset_box'
M.outlined_button = require 'src.widget.widgets.outlined_button'
M.overflow = require 'src.widget.widgets.overflow'
M.padding = require 'src.widget.widgets.padding'
M.positioned = require 'src.widget.widgets.positioned'
M.progress_indicator = require 'src.widget.widgets.progress_indicator'
M.sized_box = require 'src.widget.widgets.sized_box'
M.slider = require 'src.widget.widgets.slider'
M.stack = require 'src.widget.widgets.stack'
M.text = require 'src.widget.widgets.text'
M.text_button = require 'src.widget.widgets.text_button'
M.tooltip = require 'src.widget.widgets.tooltip'
M.transform_box = require 'src.widget.widgets.transform_box'

for _, source in ipairs({ M.align, M.basic, M.button, M.button_base, M.button_style, M.constraints, M.container, M.custom_paint, M.decorated_box, M.elevated_button, M.flex, M.gesture_detector, M.hover_text, M.icon, M.icon_button, M.layout, M.offset_box, M.outlined_button, M.overflow, M.padding, M.positioned, M.progress_indicator, M.sized_box, M.slider, M.stack, M.text, M.text_button, M.tooltip, M.transform_box }) do
    for name, value in pairs(source) do
        if M[name] == nil then
            M[name] = value
        end
    end
end

return M
