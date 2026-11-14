-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

---@class elxosc.widget :
--- elxosc.src.widget,
--- elxosc.src.widget.ambient,
--- elxosc.src.widget.app,
--- elxosc.src.widget.binding,
--- elxosc.src.widget.build_owner,
--- elxosc.src.widget.build_scope,
--- elxosc.src.widget.builder,
--- elxosc.src.widget.element,
--- elxosc.src.widget.key,
--- elxosc.src.widget.navigation,
--- elxosc.src.widget.overlay,
--- elxosc.src.widget.provider,
--- elxosc.src.widget.state,
--- elxosc.src.widget.visibility,
--- elxosc.src.widget.widget,
--- elxosc.src.widget.widgets_binding
local M = {}

local ambient = require 'src.widget.ambient'
local app = require 'src.widget.app'
local binding = require 'src.widget.binding'
local build_owner = require 'src.widget.build_owner'
local build_scope = require 'src.widget.build_scope'
local builder = require 'src.widget.builder'
local element = require 'src.widget.element'
local key = require 'src.widget.key'
local navigation = require 'src.widget.navigation'
local overlay = require 'src.widget.overlay'
local provider = require 'src.widget.provider'
local state = require 'src.widget.state'
local visibility = require 'src.widget.visibility'
local widget = require 'src.widget.widget'
local widgets_binding = require 'src.widget.widgets_binding'

for _, source in ipairs({
    require 'src.widget',
    ambient,
    app,
    binding,
    build_owner,
    build_scope,
    builder,
    element,
    key,
    navigation,
    overlay,
    provider,
    state,
    visibility,
    widget,
    widgets_binding,
}) do
    for name, value in pairs(source) do
        if M[name] == nil then
            M[name] = value
        end
    end
end

return M
