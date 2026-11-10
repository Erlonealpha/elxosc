-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

---@class elxosc.text : elxosc.src.text.paragraph, elxosc.src.text.text_layout, elxosc.src.text.text_style
local M = {}

M.paragraph = require 'src.text.paragraph'
M.text_layout = require 'src.text.text_layout'
M.text_style = require 'src.text.text_style'

for _, source in ipairs({
    M.paragraph,
    M.text_layout,
    M.text_style,
}) do
    for name, value in pairs(source) do
        if M[name] == nil then
            M[name] = value
        end
    end
end

return M
