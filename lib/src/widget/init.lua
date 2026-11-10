-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Single entry point for the widget layer: `require 'src.widget'`.
--
-- Aggregates the widget/element/state core with the widget library, which is
-- what the (later) definition sandbox will expose to other scripts.

local widget_mod = require 'src.widget.widget'
local builder_mod = require 'src.widget.builder'
local element_mod = require 'src.widget.element'
local state_mod = require 'src.widget.state'
local key_mod = require 'src.widget.key'
local build_owner_mod = require 'src.widget.build_owner'
local build_scope_mod = require 'src.widget.build_scope'
local binding_mod = require 'src.widget.binding'
local widgets_binding_mod = require 'src.widget.widgets_binding'
local provider_mod = require 'src.widget.provider'
local player_context_mod = require 'src.widget.player_context'
local ambient_mod = require 'src.widget.ambient'
local actions_mod = require 'src.widget.actions'
local visibility_mod = require 'src.widget.visibility'
local overlay_mod = require 'src.widget.overlay'
local navigation_mod = require 'src.widget.navigation'
local app_mod = require 'src.widget.app'
local player_mod = require 'src.widget.player'

---@class elxosc.src.widget : elxosc.src.widget.widget, elxosc.src.widget.builder, elxosc.src.widget.element, elxosc.src.widget.state, elxosc.src.widget.key, elxosc.src.widget.build_owner, elxosc.src.widget.build_scope, elxosc.src.widget.binding, elxosc.src.widget.widgets_binding, elxosc.src.widget.provider, elxosc.src.widget.player_context, elxosc.src.widget.ambient, elxosc.src.widget.actions, elxosc.src.widget.visibility, elxosc.src.widget.overlay, elxosc.src.widget.navigation, elxosc.src.widget.app, elxosc.src.widget.player, elxosc.src.widget.widgets.layout, elxosc.src.widget.widgets.basic, elxosc.src.widget.bind
local M = {}

for _, mod in ipairs({
    widget_mod,
    builder_mod,
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
    player_mod,
}) do
    for name, value in pairs(mod) do
        M[name] = value
    end
end

for _, mod in ipairs({
    require 'src.widget.widgets.layout',
    require 'src.widget.widgets.basic',
    require 'src.widget.bind',
}) do
    for name, value in pairs(mod) do
        M[name] = value
    end
end

return M
