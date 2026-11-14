-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Public layer members retain their direct-source identity.
local exports = require('export').new()

local export = exports.export

export('layout', require 'src.layout.constraints', true)

---@class elxosc.layout : elxosc.src.layout.constraints
local M = exports.get('layout')

return M
