-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Public layer members retain their direct-source identity.
---@namespace elxosc
---@using elxosc

local exports = require('export').new()

local export = exports.export

export('backends', require 'src.backends.ass_canvas', true)
export('backends', require 'src.backends.ass_text_layout', true)
export('backends', require 'src.backends.record', true)

---@class mod.backends :
--- mod.src.backends.ass_canvas,
--- mod.src.backends.ass_text_layout,
--- mod.src.backends.record
local M = exports.get('backends')

return M
