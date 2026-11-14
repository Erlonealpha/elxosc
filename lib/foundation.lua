-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Public layer members retain their direct-source identity.
---@namespace elxosc
---@using elxosc

local exports = require('export').new()

local export = exports.export

export('foundation', require 'src.foundation.anchor', true)
export('foundation', require 'src.foundation.binding_base', true)
export('foundation', require 'src.foundation.color', true)
export('foundation', require 'src.foundation.geometry', true)
export('foundation', require 'src.foundation.key', true)
export('foundation', require 'src.foundation.key_event', true)
export('foundation', require 'src.foundation.pointer_event', true)
export('foundation', require 'src.foundation.transform', true)

---@class mod.foundation : mod.src.foundation.anchor, mod.src.foundation.binding_base, mod.src.foundation.color, mod.src.foundation.geometry, mod.src.foundation.key, mod.src.foundation.key_event, mod.src.foundation.pointer_event, mod.src.foundation.transform
local M = exports.get('foundation')

return M
