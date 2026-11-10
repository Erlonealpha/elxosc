-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Central collection only; registration and builtins policy belong to mpv_define.
local foundation = require 'foundation.exports'
local painting = require 'painting.exports'
local text = require 'text.exports'
local widgets = require 'widget.exports'
local player = require 'widget.player.exports'

---@alias ExtensionPackage elxosc.foundation.exports | elxosc.painting.exports | elxosc.text.exports | elxosc.widget.exports | elxosc.widget.player.exports
---@alias ExtensionPackages ExtensionPackage[]

---@class elxosc.libs.exports
local M = {}

---@return ExtensionPackages
function M.collect()
    return { foundation, painting, text, widgets, player }
end

return M
