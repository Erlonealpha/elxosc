-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

---@class elxosc.widget.player : elxosc.src.widget.player.app, elxosc.src.widget.player.components, elxosc.src.widget.player.controls, elxosc.src.widget.player.data, elxosc.src.widget.player.description, elxosc.src.widget.player.extension_controls, elxosc.src.widget.player.geometry, elxosc.src.widget.player.icon_map, elxosc.src.widget.player.layout, elxosc.src.widget.player.metadata, elxosc.src.widget.player.text_controls, elxosc.src.widget.player.theme, elxosc.src.widget.player.timeline, elxosc.src.widget.player.tooltip, elxosc.src.widget.player.visuals
local M = {}

M.app = require 'src.widget.player.app'
M.components = require 'src.widget.player.components'
M.controls = require 'src.widget.player.controls'
M.data = require 'src.widget.player.data'
M.description = require 'src.widget.player.description'
M.extension_controls = require 'src.widget.player.extension_controls'
M.geometry = require 'src.widget.player.geometry'
M.icon_map = require 'src.widget.player.icon_map'
M.layout = require 'src.widget.player.layout'
M.metadata = require 'src.widget.player.metadata'
M.text_controls = require 'src.widget.player.text_controls'
M.theme = require 'src.widget.player.theme'
M.timeline = require 'src.widget.player.timeline'
M.tooltip = require 'src.widget.player.tooltip'
M.visuals = require 'src.widget.player.visuals'

for _, source in ipairs({ M.app, M.components, M.controls, M.data, M.description, M.extension_controls, M.geometry, M.icon_map, M.layout, M.metadata, M.text_controls, M.theme, M.timeline, M.tooltip, M.visuals }) do
    for name, value in pairs(source) do
        if M[name] == nil then
            M[name] = value
        end
    end
end

return M
