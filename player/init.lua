-- Public aggregate for the host-independent player composition layer.

local region_mod = require 'player.region'
local registry_mod = require 'player.registry'
local scaffold_mod = require 'player.scaffold'

return {
    Region = region_mod.Region,
    PageContribution = registry_mod.PageContribution,
    PagesRegistry = registry_mod.PagesRegistry,
    Grid = scaffold_mod.Grid,
    Main = scaffold_mod.Main,
    More = scaffold_mod.More,
    PlayerScaffold = scaffold_mod.PlayerScaffold,
}
