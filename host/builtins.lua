-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

---@namespace elxosc
---@using elxosc

local dsl = require 'define.src.dsl'

--- Class factories and selected Lua utilities; components use explicit imports.
---@class mod.host.builtins
---@field rawlen (fun(value: table | string): integer)? only when provided by the runtime
---@field utf8   table?                                 only when provided by the runtime
local M = {
    new_widget = dsl.new_widget,
    new_state = dsl.new_state,

    next = next,
    pairs = pairs,
    ipairs = ipairs,
    tonumber = tonumber,
    tostring = tostring,
    rawequal = rawequal,
    rawget = rawget,
    rawlen = rawget(_G, 'rawlen'), -- Optional Lua 5.2 compatibility.
    rawset = rawset,
    select = select,
    type = type,
    unpack = unpack,
    pcall = pcall,
    xpcall = xpcall,
    error = error,
    _VERSION = _VERSION,

    math = math,
    table = table,
    utf8 = rawget(_G, 'utf8')      -- Optional Lua 5.3 library.
}

return M
