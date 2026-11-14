-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

---@class elxosc.backends : elxosc.src.backends.ass_canvas, elxosc.src.backends.ass_text_layout, elxosc.src.backends.record
local M = {}

local ass_canvas = require 'src.backends.ass_canvas'
local ass_text_layout = require 'src.backends.ass_text_layout'
local record = require 'src.backends.record'

for _, source in ipairs({
    ass_canvas,
    ass_text_layout,
    record,
}) do
    for name, value in pairs(source) do
        if M[name] == nil then
            M[name] = value
        end
    end
end

return M
