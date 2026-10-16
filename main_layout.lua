-- Compatibility facade for the application's original nine-region scaffold.
-- The full Root -> PlayerScaffold -> Main/grid/more composition lives in
-- `player/`; this entry point intentionally keeps the legacy render-root shape.

local scaffold_mod = require 'player.scaffold'

local M = {}

-- Every region keeps a render node even before another script binds content.
-- This makes the scaffold a stable three-by-three grid during the define
-- window as well as after bindings have been applied.
local SLOT = scaffold_mod.LEGACY_SLOT

---@param middle_child? Widget
---@return Widget
function M.build_scaffold(middle_child)
    if not middle_child then
        local demo_mod = require 'demo'
        middle_child = demo_mod.Demo()
    end

    return scaffold_mod.build_grid(middle_child)
end

M.SLOT = SLOT

return M
