-- Public player members; component selection belongs to the player layer.
local exports = require('export').new()
local export = exports.export

export('player', require 'player.src.components')

---@class elxosc.mod.player : elxosc.mod.player.src.components
local M = exports.get('player')
return M
