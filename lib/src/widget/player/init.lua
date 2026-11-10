-- Default player components and their public aggregate.

local app_mod = require 'src.widget.player.app'
local timeline_mod = require 'src.widget.player.timeline'
local icon_map = require 'src.widget.player.icon_map'
local theme_mod = require 'src.widget.player.theme'
local layout_mod = require 'src.widget.player.layout'
local tooltip_mod = require 'src.widget.player.tooltip'
local metadata_mod = require 'src.widget.player.metadata'
local extension_controls_mod = require 'src.widget.player.extension_controls'
local text_controls_mod = require 'src.widget.player.text_controls'

---@class elxosc.src.widget.player : elxosc.src.widget.player.app, elxosc.src.widget.player.timeline, elxosc.src.widget.player.icon_map, elxosc.src.widget.player.theme, elxosc.src.widget.player.layout, elxosc.src.widget.player.tooltip, elxosc.src.widget.player.metadata, elxosc.src.widget.player.extension_controls, elxosc.src.widget.player.text_controls
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
