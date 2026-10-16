-- Compatibility name for callers that refer to the composition layer as Pages.

local registry_mod = require 'player.registry'
local region_mod = require 'player.region'
local scaffold_mod = require 'player.scaffold'

return {
    Region = region_mod.Region,
    PageContribution = registry_mod.PageContribution,
    PagesRegistry = registry_mod.PagesRegistry,
    PlayerScaffold = scaffold_mod.PlayerScaffold,
}
