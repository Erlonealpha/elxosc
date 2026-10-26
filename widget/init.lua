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
local build_scope_mod = require 'widget.build_scope'
local binding_mod = require 'widget.binding'
local widgets_binding_mod = require 'widget.widgets_binding'
local provider_mod = require 'widget.provider'
local player_context_mod = require 'widget.player_context'
local ambient_mod = require 'widget.ambient'
local actions_mod = require 'widget.actions'
local visibility_mod = require 'widget.visibility'
local overlay_mod = require 'widget.overlay'
local navigation_mod = require 'widget.navigation'
local app_mod = require 'widget.app'

local M = {}

for _, mod in ipairs({
    widget_mod,
    element_mod,
    state_mod,
    key_mod,
    build_owner_mod,
    build_scope_mod,
    binding_mod,
    widgets_binding_mod,
    provider_mod,
    player_context_mod,
    ambient_mod,
    actions_mod,
    visibility_mod,
    overlay_mod,
    navigation_mod,
    app_mod,
}) do
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
