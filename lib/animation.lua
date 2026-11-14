-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Public layer members retain their direct-source identity.
local exports = require('export').new()

local export = exports.export

export('animation', require 'src.animation.controller', true)
export('animation', require 'src.animation.curve', true)
export('animation', require 'src.animation.tween', true)

---@class elxosc.animation :
--- elxosc.src.animation.controller,
--- elxosc.src.animation.curve,
--- elxosc.src.animation.tween
local M = exports.get('animation')

return M
