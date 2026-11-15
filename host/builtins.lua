-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

---@namespace elxosc
---@using elxosc

local dsl = require 'define.src.dsl'

--- Default class factories; components and values are obtained through imports.
---@class mod.host.builtins
local M = {
    new_widget = dsl.new_widget,
    new_state = dsl.new_state,
}

return M
