-- Refactor stage 6/7/8 presentation vocabulary, plan materialization and region cache.

local F = require('framework')

local mp_stub = require('mp_stub')
mp_stub.install()

local fake = mp_stub.fake
local presentation = require('host.presentation_host')
local overlay_host = require('host.overlay_host')
local basic_widgets = require('widget.widgets.basic')
local player_overlay = require('player.overlay')
local geometry = require('foundation.geometry')

local PresentationHost = presentation.PresentationHost
local PresentationSurface = presentation.PresentationSurface
local RegionSnapshot = presentation.RegionSnapshot
local OverlayDeclaration = overlay_host.OverlayDeclaration
local Overlay = player_overlay.Overlay
local OverlayEntry = player_overlay.OverlayEntry
local Text = basic_widgets.Text
local Offset = geometry.Offset

F.section('presentation host: surfaces, plans and region snapshots')

F.test('presentation exports preserve the physical host identities', function()
    F.eq(PresentationHost, overlay_host.OverlayHost, 'host alias preserves one owner class')
    F.eq(PresentationSurface, overlay_host.LayerRecord, 'surface alias preserves one record class')
    F.ok(RegionSnapshot() ~= nil, 'region snapshots are constructible')
    F.eq(RegionSnapshot().active, false, 'new snapshots are inactive')
end)

F.test('named surfaces share clock scheduler input and own presenters', function()
    mp_stub.reset()
    local host = PresentationHost()
    local default_surface = host:create_surface('default', Text('main'), {
        surface_policy = 'default',
        input_policy = 'passive',
    })
    local extension_surface = host:create_surface('extension', Text('extension'), {
        surface_policy = 'extension',
        input_policy = 'passive',
    })
    local popup_surface = host:create_surface('popup', Text('popup'), {
        surface_policy = 'popup',
        input_policy = 'exclusive',
    })
    F.eq(default_surface.z, presentation.Z_POLICIES.default, 'default uses host policy')
    F.eq(extension_surface.z, presentation.Z_POLICIES.extension, 'extension uses host policy')
    F.eq(popup_surface.z, presentation.Z_POLICIES.popup, 'popup uses host policy')
    F.ok(default_surface.presenter ~= extension_surface.presenter,
        'surfaces have independent ASS presenters')
    local default_binding = default_surface.binding --[[@as WidgetBinding]]
    local extension_binding = extension_surface.binding --[[@as WidgetBinding]]
    local popup_binding = popup_surface.binding --[[@as WidgetBinding]]
    F.ok(default_binding.build_owner.scheduler == host.scheduler,
        'surfaces share one scheduler')
    F.ok(extension_binding.build_owner.scheduler == host.scheduler,
        'extension shares the scheduler')
    F.ok(popup_binding.build_owner.scheduler == host.scheduler,
        'popup shares the scheduler')
    F.eq(#fake.overlays, 3, 'three named surfaces create three presenters')
    host:shutdown()
end)

F.test('logical plans group entries into controlled physical surfaces', function()
    mp_stub.reset()
    local host = PresentationHost()
    local logical = Overlay()
    logical:insert(OverlayEntry({
        key = 'main',
        kind = 'main',
        child = Text('main'),
    }))
    logical:insert(OverlayEntry({
        key = 'extension',
        kind = 'extension',
        child = Text('extension'),
        input_policy = 'passive',
    }))
    logical:insert(OverlayEntry({
        key = 'popup',
        kind = 'popup',
        child = Text('popup'),
        input_policy = 'exclusive',
    }))
    local surfaces = host:apply_presentation_plan(logical:plan())
    F.ok(surfaces.default ~= nil, 'main plan entry maps to default surface')
    F.ok(surfaces.extension ~= nil, 'extension plan entry maps to extension surface')
    F.ok(surfaces.popup ~= nil, 'popup plan entry maps to popup surface')
    F.eq(surfaces.popup.input_policy, 'exclusive', 'popup policy is derived from plan')
    F.raises(function()
        host:create_surface('bad', Text('bad'), { surface_policy = 'unknown' --[[@as any]] })
    end, 'overlay z_policy', 'arbitrary surface names are rejected')
    host:shutdown()
end)

F.test('region snapshots are reused across moves and invalidated by input changes', function()
    mp_stub.reset()
    local host = PresentationHost()
    local surface = host:create_surface('default', Text('main'), {
        surface_policy = 'default',
        input_policy = 'interactive',
    })
    host:render()
    local calls = 0
    local owner = surface.owner
    local pointer_regions = owner.pointer_regions
    owner.pointer_regions = function()
        calls = calls + 1
        return pointer_regions(owner)
    end
    local first = host.input_router:pointer_regions()
    F.eq(#first, 0, 'non-interactive text exports no regions')
    local initial_calls = calls
    for _ = 1, 100 do
        host.input_router:dispatch_pointer_result('move', Offset(0, 0))
    end
    F.eq(calls, initial_calls, 'moves do not rebuild a clean region snapshot')
    local generation = surface.region_snapshot.generation
    owner:mark_needs_input()
    host.input_router:pointer_regions()
    local new_generation = surface.region_snapshot.generation
    F.ok(new_generation > generation,
        'explicit input invalidation advances the snapshot generation')
    host:hide_surface('default')
    F.ok(not surface.region_snapshot.active, 'hidden surface snapshot is inactive')
    host:show_surface('default')
    F.ok(surface.region_snapshot.active, 'show restores the active region snapshot')
    host.input_router:pointer_regions()
    F.ok(surface.region_snapshot.active, 'visible surface refreshes on demand')
    host:shutdown()
end)

F.test('Define declarations enter the plan adapter without exposing presenters', function()
    mp_stub.reset()
    local host = PresentationHost()
    local declarations = {
        OverlayDeclaration('extension-card', Text('extension'), {
            z_policy = 'extension',
            input_policy = 'passive',
        }, 'scope-a', 1),
        OverlayDeclaration('popup-card', Text('popup'), {
            z_policy = 'popup',
            input_policy = 'exclusive',
        }, 'scope-b', 2),
    }
    local surfaces = host:mount_declarations_as_plan(declarations)
    F.ok(surfaces.extension ~= nil, 'Define extension declaration maps to extension')
    F.ok(surfaces.popup ~= nil, 'Define popup declaration maps to popup')
    F.ok(declarations[1].root_widget ~= nil, 'declaration remains a data record')
    F.eq(declarations[1].presenter, nil, 'declaration has no presenter access')
    host:shutdown()
end)
