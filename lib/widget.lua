-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

---@class elxosc.widget : elxosc.src.widget, elxosc.src.widget.actions, elxosc.src.widget.ambient, elxosc.src.widget.app, elxosc.src.widget.bind, elxosc.src.widget.binding, elxosc.src.widget.build_owner, elxosc.src.widget.build_scope, elxosc.src.widget.builder, elxosc.src.widget.dsl, elxosc.src.widget.element, elxosc.src.widget.key, elxosc.src.widget.navigation, elxosc.src.widget.overlay, elxosc.src.widget.player_context, elxosc.src.widget.provider, elxosc.src.widget.slot, elxosc.src.widget.state, elxosc.src.widget.visibility, elxosc.src.widget.widget, elxosc.src.widget.widgets_binding
local M = {}

M.actions = require 'src.widget.actions'
M.ambient = require 'src.widget.ambient'
M.app = require 'src.widget.app'
M.bind_module = require 'src.widget.bind'
M.binding = require 'src.widget.binding'
M.build_owner = require 'src.widget.build_owner'
M.build_scope = require 'src.widget.build_scope'
M.builder = require 'src.widget.builder'
M.dsl = require 'src.widget.dsl'
M.element = require 'src.widget.element'
M.key = require 'src.widget.key'
M.navigation = require 'src.widget.navigation'
M.overlay = require 'src.widget.overlay'
M.player_context = require 'src.widget.player_context'
M.provider = require 'src.widget.provider'
M.slot = require 'src.widget.slot'
M.state = require 'src.widget.state'
M.visibility = require 'src.widget.visibility'
M.widget = require 'src.widget.widget'
M.widgets_binding = require 'src.widget.widgets_binding'
M.player = require 'widget.player'
M.widgets = require 'widget.widgets'

for _, source in ipairs({
    require 'src.widget',
    M.actions,
    M.ambient,
    M.app,
    M.bind_module,
    M.binding,
    M.build_owner,
    M.build_scope,
    M.builder,
    M.dsl,
    M.element,
    M.key,
    M.navigation,
    M.overlay,
    M.player_context,
    M.provider,
    M.slot,
    M.state,
    M.visibility,
    M.widget,
    M.widgets_binding,
}) do
    for name, value in pairs(source) do
        if M[name] == nil then
            M[name] = value
        end
    end
end

return M
