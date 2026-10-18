-- Compatibility name for callers that refer to the composition layer as Pages.

local registry_mod = require 'player.registry'
local region_mod = require 'player.region'
local scaffold_mod = require 'player.scaffold'
local navigation_mod = require 'player.navigation'
local overlay_mod = require 'player.overlay'

return {
    Region = region_mod.Region,
    PageContribution = registry_mod.PageContribution,
    PagesRegistry = registry_mod.PagesRegistry,
    ExtensionGrid = scaffold_mod.ExtensionGrid,
    Grid = scaffold_mod.Grid,
    Main = scaffold_mod.Main,
    More = scaffold_mod.More,
    Extension = scaffold_mod.Extension,
    PlayerScaffold = scaffold_mod.PlayerScaffold,
    Page = navigation_mod.Page,
    Route = navigation_mod.Route,
    RouteResult = navigation_mod.RouteResult,
    Navigator = navigation_mod.Navigator,
    NavigatorState = navigation_mod.NavigatorState,
    OverlayEntry = overlay_mod.OverlayEntry,
    Overlay = overlay_mod.Overlay,
    Theatre = overlay_mod.Theatre,
    ModalBarrier = overlay_mod.ModalBarrier,
    PopupRoute = overlay_mod.PopupRoute,
}
