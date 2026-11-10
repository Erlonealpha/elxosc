-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

---@class elxosc.scheduler : elxosc.src.scheduler.frame_clock, elxosc.src.scheduler.scheduler, elxosc.src.scheduler.scheduler_binding, elxosc.src.scheduler.ticker
local M = {}

M.frame_clock = require 'src.scheduler.frame_clock'
M.scheduler = require 'src.scheduler.scheduler'
M.scheduler_binding = require 'src.scheduler.scheduler_binding'
M.ticker = require 'src.scheduler.ticker'

for _, source in ipairs({
    M.frame_clock,
    M.scheduler,
    M.scheduler_binding,
    M.ticker,
}) do
    for name, value in pairs(source) do
        if M[name] == nil then
            M[name] = value
        end
    end
end

return M
