-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Public layer members retain their direct-source identity.
---@namespace elxosc
---@using elxosc

local exports = require('export').new()

local export = exports.export

export('scheduler', require 'src.scheduler.frame_clock', true)
export('scheduler', require 'src.scheduler.scheduler', true)
export('scheduler', require 'src.scheduler.scheduler_binding', true)
export('scheduler', require 'src.scheduler.ticker', true)

---@class mod.scheduler:
--- mod.src.scheduler.frame_clock,
--- mod.src.scheduler.scheduler,
--- mod.src.scheduler.scheduler_binding, mod.src.scheduler.ticker
local M = exports.get('scheduler')

return M
