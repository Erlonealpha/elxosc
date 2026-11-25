-- Public player members; component selection belongs to the player layer.
---@namespace elxosc
---@using elxosc
---@using elxosc.player

local exports = require('export').new()

local export = exports.export

export('player', require 'player.src.components')

---@class mod.player: mod.player.src.components
local M = exports.get('player')
return M
