-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Single entry point for the widget layer: `require 'widget'`.
--
-- Aggregates the widget/element/state core with the widget library, which is
-- what the (later) definition sandbox will expose to other scripts.

local widget_mod = require 'widget.widget'
local element_mod = require 'widget.element'
local state_mod = require 'widget.state'
local key_mod = require 'widget.key'
local build_owner_mod = require 'widget.build_owner'
local binding_mod = require 'widget.binding'

local M = {}

for _, mod in ipairs({ widget_mod, element_mod, state_mod, key_mod, build_owner_mod, binding_mod }) do
    for name, value in pairs(mod) do
        M[name] = value
    end
end

for _, mod in ipairs({
    require 'widget.widgets.layout',
    require 'widget.widgets.basic',
    require 'widget.bind',
}) do
    for name, value in pairs(mod) do
        M[name] = value
    end
end

return M
