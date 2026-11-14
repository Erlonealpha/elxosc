-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

---@class elxosc.widget.widgets : elxosc.src.widget.widgets.align, elxosc.src.widget.widgets.basic, elxosc.src.widget.widgets.button, elxosc.src.widget.widgets.button_base, elxosc.src.widget.widgets.button_style, elxosc.src.widget.widgets.constraints, elxosc.src.widget.widgets.container, elxosc.src.widget.widgets.custom_paint, elxosc.src.widget.widgets.decorated_box, elxosc.src.widget.widgets.elevated_button, elxosc.src.widget.widgets.flex, elxosc.src.widget.widgets.gesture_detector, elxosc.src.widget.widgets.hover_text, elxosc.src.widget.widgets.icon, elxosc.src.widget.widgets.icon_button, elxosc.src.widget.widgets.layout, elxosc.src.widget.widgets.offset_box, elxosc.src.widget.widgets.outlined_button, elxosc.src.widget.widgets.overflow, elxosc.src.widget.widgets.padding, elxosc.src.widget.widgets.positioned, elxosc.src.widget.widgets.progress_indicator, elxosc.src.widget.widgets.sized_box, elxosc.src.widget.widgets.slider, elxosc.src.widget.widgets.stack, elxosc.src.widget.widgets.text, elxosc.src.widget.widgets.text_button, elxosc.src.widget.widgets.tooltip, elxosc.src.widget.widgets.transform_box
local M = {}

local align = require 'src.widget.widgets.align'
local basic = require 'src.widget.widgets.basic'
local button = require 'src.widget.widgets.button'
local button_base = require 'src.widget.widgets.button_base'
local button_style = require 'src.widget.widgets.button_style'
local constraints = require 'src.widget.widgets.constraints'
local container = require 'src.widget.widgets.container'
local custom_paint = require 'src.widget.widgets.custom_paint'
local decorated_box = require 'src.widget.widgets.decorated_box'
local elevated_button = require 'src.widget.widgets.elevated_button'
local flex = require 'src.widget.widgets.flex'
local gesture_detector = require 'src.widget.widgets.gesture_detector'
local hover_text = require 'src.widget.widgets.hover_text'
local icon = require 'src.widget.widgets.icon'
local icon_button = require 'src.widget.widgets.icon_button'
local layout = require 'src.widget.widgets.layout'
local offset_box = require 'src.widget.widgets.offset_box'
local outlined_button = require 'src.widget.widgets.outlined_button'
local overflow = require 'src.widget.widgets.overflow'
local padding = require 'src.widget.widgets.padding'
local positioned = require 'src.widget.widgets.positioned'
local progress_indicator = require 'src.widget.widgets.progress_indicator'
local sized_box = require 'src.widget.widgets.sized_box'
local slider = require 'src.widget.widgets.slider'
local stack = require 'src.widget.widgets.stack'
local text = require 'src.widget.widgets.text'
local text_button = require 'src.widget.widgets.text_button'
local tooltip = require 'src.widget.widgets.tooltip'
local transform_box = require 'src.widget.widgets.transform_box'

for _, source in ipairs({ align, basic, button, button_base, button_style, constraints, container, custom_paint, decorated_box, elevated_button, flex, gesture_detector, hover_text, icon, icon_button, layout, offset_box, outlined_button, overflow, padding, positioned, progress_indicator, sized_box, slider, stack, text, text_button, tooltip, transform_box }) do
    for name, value in pairs(source) do
        if M[name] == nil then
            M[name] = value
        end
    end
end

return M
