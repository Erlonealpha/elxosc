-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

local paint = require 'painting.paint'
local text_paint = require 'painting.text_paint'
local path = require 'painting.path'
local canvas = require 'painting.canvas'

---@alias elxosc.painting.exports.data elxosc.painting.paint & elxosc.painting.text_paint & elxosc.painting.path & elxosc.painting.canvas
---@type elxosc.painting.exports.data
local exports = {}
for _, source in ipairs({ paint, text_paint, path, canvas }) do
    for name, value in pairs(source) do
        exports[name] = value
    end
end

---@class elxosc.painting.exports : DefinePackage<elxosc.painting.exports.data>
local M = { name = 'painting', exports = exports }

return M
