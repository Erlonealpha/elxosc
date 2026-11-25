-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Public layer members retain their direct-source identity.
---@namespace elxosc
---@using elxosc

local exports = require('export').new()

local export = exports.export

export('text', require 'src.text.paragraph', true)
export('text', require 'src.text.grapheme', true)
export('text', require 'src.text.text_layout', true)
export('text', require 'src.text.text_style', true)

---@class mod.text: mod.src.text.paragraph, mod.src.text.grapheme, mod.src.text.text_layout, mod.src.text.text_style
local M = exports.get('text')

return M
