-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Shared values available to extension packages.
local geometry = require 'foundation.geometry'
local color = require 'foundation.color'
local transform = require 'foundation.transform'
local anchor = require 'foundation.anchor'

---@alias elxosc.foundation.exports.data elxosc.foundation.geometry & elxosc.foundation.color & elxosc.foundation.transform & elxosc.foundation.anchor
---@type elxosc.foundation.exports.data
local exports = {}
for _, source in ipairs({ geometry, color, transform, anchor }) do
    for name, value in pairs(source) do
        exports[name] = value
    end
end

---@class elxosc.foundation.exports : DefinePackage<elxosc.foundation.exports.data>
local M = { name = 'foundation', exports = exports }

return M
