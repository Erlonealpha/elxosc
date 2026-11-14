-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Public layer members retain their direct-source identity.
local exports = require('export').new()

local export = exports.export

export('scheduler', require 'src.scheduler.frame_clock', true)
export('scheduler', require 'src.scheduler.scheduler', true)
export('scheduler', require 'src.scheduler.scheduler_binding', true)
export('scheduler', require 'src.scheduler.ticker', true)

---@class elxosc.scheduler :
--- elxosc.src.scheduler.frame_clock,
--- elxosc.src.scheduler.scheduler,
--- elxosc.src.scheduler.scheduler_binding, elxosc.src.scheduler.ticker
local M = exports.get('scheduler')

return M
