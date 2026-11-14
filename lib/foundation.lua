-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

---@class elxosc.foundation : elxosc.src.foundation.anchor, elxosc.src.foundation.binding_base, elxosc.src.foundation.color, elxosc.src.foundation.geometry, elxosc.src.foundation.key, elxosc.src.foundation.key_event, elxosc.src.foundation.pointer_event, elxosc.src.foundation.transform
local M = {}

local anchor = require 'src.foundation.anchor'
local binding_base = require 'src.foundation.binding_base'
local color = require 'src.foundation.color'
local geometry = require 'src.foundation.geometry'
local key = require 'src.foundation.key'
local key_event = require 'src.foundation.key_event'
local pointer_event = require 'src.foundation.pointer_event'
local transform = require 'src.foundation.transform'

for _, source in ipairs({
    anchor,
    binding_base,
    color,
    geometry,
    key,
    key_event,
    pointer_event,
    transform,
}) do
    for name, value in pairs(source) do
        if M[name] == nil then
            M[name] = value
        end
    end
end

return M
