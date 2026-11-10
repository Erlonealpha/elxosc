-- Default player components and their public aggregate.

local app_mod = require 'widget.player.app'
local timeline_mod = require 'widget.player.timeline'
local icon_map = require 'widget.player.icon_map'
local theme_mod = require 'widget.player.theme'
local layout_mod = require 'widget.player.layout'
local tooltip_mod = require 'widget.player.tooltip'
local metadata_mod = require 'widget.player.metadata'
local extension_controls_mod = require 'widget.player.extension_controls'
local text_controls_mod = require 'widget.player.text_controls'

---@class elxosc.widget.player : elxosc.widget.player.app, elxosc.widget.player.timeline, elxosc.widget.player.icon_map, elxosc.widget.player.theme, elxosc.widget.player.layout, elxosc.widget.player.tooltip, elxosc.widget.player.metadata, elxosc.widget.player.extension_controls, elxosc.widget.player.text_controls
local M = {}
M.PlayerIcons = icon_map
M.PlayerMain = app_mod.Main
for _, mod in ipairs({ app_mod, timeline_mod, icon_map, theme_mod, layout_mod, tooltip_mod, metadata_mod,
    extension_controls_mod, text_controls_mod }) do
    for name, value in pairs(mod) do
        M[name] = value
    end
end

return M
