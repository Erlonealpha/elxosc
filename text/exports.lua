-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

local style = require 'text.text_style'
local paragraph = require 'text.paragraph'

---@alias elxosc.text.exports.data elxosc.text.text_style & elxosc.text.paragraph
---@type elxosc.text.exports.data
local exports = {}
for _, source in ipairs({ style, paragraph }) do
    for name, value in pairs(source) do
        exports[name] = value
    end
end

---@class elxosc.text.exports : DefinePackage<elxosc.text.exports.data>
local M = { name = 'text', exports = exports }

return M
