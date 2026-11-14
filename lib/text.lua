-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Public layer members retain their direct-source identity.
local exports = require('export').new()

local export = exports.export

export('text', require 'src.text.paragraph', true)
export('text', require 'src.text.text_layout', true)
export('text', require 'src.text.text_style', true)

---@class elxosc.text : elxosc.src.text.paragraph, elxosc.src.text.text_layout, elxosc.src.text.text_style
local M = exports.get('text')

return M
