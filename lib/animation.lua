-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

---@class elxosc.animation : elxosc.src.animation, elxosc.src.animation.controller, elxosc.src.animation.curve, elxosc.src.animation.tween
local M = {}

local controller = require 'src.animation.controller'
local curve = require 'src.animation.curve'
local tween = require 'src.animation.tween'

for _, source in ipairs({
    require 'src.animation',
    controller,
    curve,
    tween,
}) do
    for name, value in pairs(source) do
        if M[name] == nil then
            M[name] = value
        end
    end
end

return M
