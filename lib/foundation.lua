-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

---@class elxosc.foundation : elxosc.src.foundation.anchor, elxosc.src.foundation.binding_base, elxosc.src.foundation.color, elxosc.src.foundation.geometry, elxosc.src.foundation.key, elxosc.src.foundation.key_event, elxosc.src.foundation.pointer_event, elxosc.src.foundation.transform
local M = {}

M.anchor = require 'src.foundation.anchor'
M.binding_base = require 'src.foundation.binding_base'
M.color = require 'src.foundation.color'
M.geometry = require 'src.foundation.geometry'
M.key = require 'src.foundation.key'
M.key_event = require 'src.foundation.key_event'
M.pointer_event = require 'src.foundation.pointer_event'
M.transform = require 'src.foundation.transform'

for _, source in ipairs({
    M.anchor,
    M.binding_base,
    M.color,
    M.geometry,
    M.key,
    M.key_event,
    M.pointer_event,
    M.transform,
}) do
    for name, value in pairs(source) do
        if M[name] == nil then
            M[name] = value
        end
    end
end

return M
