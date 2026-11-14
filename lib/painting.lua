-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Public layer members retain their direct-source identity.
---@namespace elxosc
---@using elxosc

local exports = require('export').new()

local export = exports.export

export('painting', require 'src.painting.canvas', true)
export('painting', require 'src.painting.paint', true)
export('painting', require 'src.painting.painting_binding', true)
export('painting', require 'src.painting.path', true)
export('painting', require 'src.painting.text_paint', true)

---@class mod.painting :
--- mod.src.painting.canvas,
--- mod.src.painting.paint,
--- mod.src.painting.painting_binding, mod.src.painting.path, mod.src.painting.text_paint
local M = exports.get('painting')

return M
