-- Complete static package inventory; no filesystem scan or incidental require order.
---@namespace elxosc
---@using elxosc
---@using elxosc.player

local exports = require('export').new()

local export = exports.export

---@class mod.player.package_catalog
local M = {}

export('player', require 'player')
export('player.actions', require 'player.src.actions')
export('player.ambients', require 'player.src.ambients')
export('player.app', require 'player.src.app')
export('player.auto_hide', require 'player.src.auto_hide')
export('player.components', require 'player.src.components')
export('player.composition', require 'player.src.composition')
export('player.context', require 'player.src.context')
export('player.controls', require 'player.src.controls')
export('player.data', require 'player.src.data')
export('player.description', require 'player.src.description')
export('player.extension_controls', require 'player.src.extension_controls')
export('player.geometry', require 'player.src.geometry')
export('player.icon_map', require 'player.src.icon_map')
export('player.layout', require 'player.src.layout')
export('player.metadata', require 'player.src.metadata')
export('player.render.timeline', require 'player.src.render.timeline')
export('player.text_controls', require 'player.src.text_controls')
export('player.theme', require 'player.src.theme')
export('player.timeline', require 'player.src.timeline')
export('player.tooltip', require 'player.src.tooltip')
export('player.visuals', require 'player.src.visuals')

---@return export.Package<export.Exports>[]
function M.collect()
    return exports.collect()
end

export('player.package_catalog', M)

return M
