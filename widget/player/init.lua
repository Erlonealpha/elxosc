-- Default player components and their public aggregate.

local app_mod = require 'widget.player.app'
local progress_mod = require 'widget.player.progress_bar'
local icon_map = require 'widget.player.icon_map'
local theme_mod = require 'widget.player.theme'
local layout_mod = require 'widget.player.layout'
local tooltip_mod = require 'widget.player.tooltip'

local M = {}
for _, mod in ipairs({ app_mod, progress_mod, icon_map, theme_mod, layout_mod, tooltip_mod }) do
    for name, value in pairs(mod) do
        M[name] = value
    end
end

return M
