-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Framework constructors and context APIs; Define owns the scope's bind function.
---@alias elxosc.widget.exports.data elxosc.widget.widget & elxosc.widget.state & elxosc.widget.key & elxosc.widget.provider & elxosc.widget.player_context & elxosc.widget.ambient & elxosc.widget.actions & elxosc.widget.visibility & elxosc.widget.overlay & elxosc.widget.navigation & elxosc.widget.app & elxosc.widget.widgets.layout & elxosc.widget.widgets.basic & elxosc.widget.slot

---@type elxosc.widget.exports.data
local exports = {}
for _, source in ipairs({
    require 'widget.widget',
    require 'widget.state',
    require 'widget.key',
    require 'widget.provider',
    require 'widget.player_context',
    require 'widget.ambient',
    require 'widget.actions',
    require 'widget.visibility',
    require 'widget.overlay',
    require 'widget.navigation',
    require 'widget.app',
    require 'widget.widgets.layout',
    require 'widget.widgets.basic',
    require 'widget.slot',
}) do
    for name, value in pairs(source) do
        exports[name] = value
    end
end

---@class elxosc.widget.exports : DefinePackage<elxosc.widget.exports.data>
local M = { name = 'widget', exports = exports }

return M
