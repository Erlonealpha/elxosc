-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Public layer members retain their direct-source identity.
local exports = require('export').new()

local export = exports.export

export('painting', require 'src.painting.canvas', true)
export('painting', require 'src.painting.paint', true)
export('painting', require 'src.painting.painting_binding', true)
export('painting', require 'src.painting.path', true)
export('painting', require 'src.painting.text_paint', true)

---@class elxosc.painting :
--- elxosc.src.painting.canvas,
--- elxosc.src.painting.paint,
--- elxosc.src.painting.painting_binding, elxosc.src.painting.path, elxosc.src.painting.text_paint
local M = exports.get('painting')

return M
