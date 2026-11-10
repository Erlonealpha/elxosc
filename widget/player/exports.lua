-- Standard extension package descriptor; registration belongs to the host.
local components = require 'widget.player.components'

---@class elxosc.widget.player.exports : DefinePackage<elxosc.widget.player.components>
local M = { name = 'player', exports = components }

return M
