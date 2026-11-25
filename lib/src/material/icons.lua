-- Named font collection; glyph layout remains in the basic Icon widget.
---@namespace elxosc
---@using elxosc
---@using elxosc.material

local resource_mod = require 'fonts.material_symbols'

---@class mod.src.material.icons
local M = {
    MaterialSymbols = resource_mod.MaterialSymbols
}
return M
