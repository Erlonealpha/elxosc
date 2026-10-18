-- Public aggregate for the host-independent player composition layer.

local region_mod = require 'player.region'
local registry_mod = require 'player.registry'
local scaffold_mod = require 'player.scaffold'
local shell_mod = require 'player.shell'
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
    ShellConfig = shell_mod.ShellConfig,
    ShellVisibilityController = shell_mod.ShellVisibilityController,
    AutoHideConfig = shell_mod.AutoHideConfig,
    AutoHideController = shell_mod.AutoHideController,
    AutoHideState = shell_mod.AutoHideState,
    AutoHide = shell_mod.AutoHide,
    PlayerShellState = shell_mod.PlayerShellState,
    PlayerShell = shell_mod.PlayerShell,
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
