-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Public layer members retain their direct-source identity.
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

---@class elxosc.foundation : elxosc.src.foundation.anchor, elxosc.src.foundation.binding_base, elxosc.src.foundation.color, elxosc.src.foundation.geometry, elxosc.src.foundation.key, elxosc.src.foundation.key_event, elxosc.src.foundation.pointer_event, elxosc.src.foundation.transform
local M = exports.get('foundation')

return M
