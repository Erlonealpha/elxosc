-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

---@class elxosc.painting : elxosc.src.painting.canvas, elxosc.src.painting.paint, elxosc.src.painting.painting_binding, elxosc.src.painting.path, elxosc.src.painting.text_paint
local M = {}

M.canvas = require 'src.painting.canvas'
M.paint = require 'src.painting.paint'
M.painting_binding = require 'src.painting.painting_binding'
M.path = require 'src.painting.path'
M.text_paint = require 'src.painting.text_paint'

for _, source in ipairs({
    M.canvas,
    M.paint,
    M.painting_binding,
    M.path,
    M.text_paint,
}) do
    for name, value in pairs(source) do
        if M[name] == nil then
            M[name] = value
        end
    end
end

return M
