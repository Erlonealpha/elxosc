-- Stage-5 host-independent logical Overlay/Theatre/PopupRoute tests.

---@diagnostic disable: undefined-field, inject-field, need-check-nil, generic-constraint-mismatch, preferred-local-alias, unused, call-non-callable

local F = require('framework')
local std = require('elxlibs.std')

local overlay_mod = require('player.overlay')
local player_api = require('player')
local navigation_mod = require('player.navigation')

local Overlay = overlay_mod.Overlay
local Theatre = overlay_mod.Theatre
local OverlayEntry = overlay_mod.OverlayEntry
local ModalBarrier = overlay_mod.ModalBarrier
local PopupRoute = overlay_mod.PopupRoute
local Page = navigation_mod.Page
local Route = navigation_mod.Route

F.section('overlay: logical Theatre and PopupRoute')

F.test('direct and aggregate overlay modules preserve exact class identities', function()
    F.eq(player_api.Overlay, Overlay, 'Overlay identity')
    F.eq(player_api.Theatre, Theatre, 'Theatre identity')
    F.eq(player_api.OverlayEntry, OverlayEntry, 'OverlayEntry identity')
    F.eq(player_api.ModalBarrier, ModalBarrier, 'ModalBarrier identity')
    F.eq(player_api.PopupRoute, PopupRoute, 'PopupRoute identity')
end)

F.test('Theatre orders Main, Extension and Popup entries deterministically', function()
    local theatre = Theatre({ main = 'main widget', extension = 'extension widget' })
    local popup_old = OverlayEntry({ key = 'old', child = 'old popup', kind = 'popup' })
    local popup_new = OverlayEntry({ key = 'new', child = 'new popup', kind = 'popup' })
    theatre:insert(popup_old)
    theatre:insert(popup_new)

    local entries = theatre:entries()
    F.eq(#entries, 4, 'stable and popup entries')
    F.eq(entries[1].kind, 'main', 'Main is first')
    F.eq(entries[2].kind, 'extension', 'Extension is second')
    F.eq(entries[3], popup_old, 'old popup precedes new popup')
    F.eq(entries[4], popup_new, 'new popup is frontmost')
    F.eq(entries[1].surface_policy, 'default', 'Main surface')
    F.eq(entries[2].surface_policy, 'extension', 'Extension surface')
    F.eq(entries[3].surface_policy, 'popup', 'Popup surface')
end)

F.test('opaque paint occlusion is independent from input policy', function()
    local overlay = Overlay()
    local background = OverlayEntry({
        key = 'background',
        kind = 'main',
        opaque = false,
        input_policy = 'interactive',
    })
    local upper = OverlayEntry({
        key = 'upper',
        kind = 'popup',
        opaque = true,
        input_policy = 'passive',
    })
    overlay:insert(background)
    overlay:insert(upper)

    local first = overlay:plan()
    F.ok(first.entries[1].occluded, 'opaque upper entry occludes background paint')
    F.eq(first.entries[2].input_policy, 'passive', 'opaque does not rewrite input policy')
    F.eq(#first.input_entries, 0, 'passive opaque entry does not claim input')

    upper:set_opaque(false)
    upper:set_input_policy('exclusive')
    local second = overlay:plan()
    F.ok(not second.entries[1].occluded, 'non-opaque entry restores background paint')
    F.eq(second.input_entries[1], upper, 'exclusive entry is frontmost input target')
    F.eq(second.entries[2].input_policy, 'exclusive', 'input policy is independently mutable')
    F.ok(second.generation > first.generation, 'policy changes advance plan generation')
end)

F.test('maintain_state controls the lifecycle adapter at occlusion boundaries', function()
    local events = {}
    local adapter = {
        mount = function(_, entry)
            events[#events + 1] = 'mount:' .. tostring(entry.key)
        end,
        unmount = function(_, entry)
            events[#events + 1] = 'unmount:' .. tostring(entry.key)
        end,
        occlude = function(_, entry)
            events[#events + 1] = 'occlude:' .. tostring(entry.key)
        end,
        resume = function(_, entry)
            events[#events + 1] = 'resume:' .. tostring(entry.key)
        end,
        dispose = function(_, entry)
            events[#events + 1] = 'dispose:' .. tostring(entry.key)
        end,
    }
    local overlay = Overlay()
    local lower = OverlayEntry({
        key = 'lower',
        kind = 'main',
        maintain_state = false,
        lifecycle_adapter = adapter,
    })
    local upper = OverlayEntry({ key = 'upper', kind = 'popup', opaque = true })
    overlay:insert(lower)
    overlay:insert(upper)
    overlay:plan()
    F.ok(not lower.mounted, 'non-maintained entry unmounts while occluded')
    F.eq(lower.lifecycle, 'occluded', 'occluded lifecycle is retained as metadata')

    upper:remove()
    local restored = overlay:plan()
    F.ok(restored.entries[1].mounted, 'entry remounts when occlusion clears')
    F.contains(table.concat(events, ','), 'unmount:lower', 'adapter sees occlusion unmount')
    F.contains(table.concat(events, ','), 'mount:lower', 'adapter sees remount')

    lower:hide()
    F.ok(not lower.visible and lower.lifecycle == 'hidden', 'hide is not remove')
    lower:show()
    F.ok(lower.visible and lower.lifecycle == 'visible', 'show restores the entry')
    lower:remove()
    F.ok(lower.disposed, 'remove completes disposal')
    F.eq(lower.owner, nil, 'disposed entry has no owner')
    F.contains(table.concat(events, ','), 'dispose:lower', 'adapter sees final dispose')
end)

F.test('PopupRoute pairs barrier and content and reuses the Route contract', function()
    local page = Page({
        key = 'dialog',
        route_kind = 'popup',
        barrier_config = { dismissible = true },
        builder = function()
            return nil
        end,
    })
    local route = PopupRoute(page)
    F.ok(std.isinstance(route, Route), 'PopupRoute is a Route subclass')
    local entries = route:overlay_entries()
    F.eq(#entries, 2, 'modal popup has two logical entries')
    F.eq(entries[1], route.barrier_entry, 'barrier is registered before content')
    F.eq(entries[2], route.content_entry, 'content follows barrier')
    F.ok(entries[1].paired_entry == entries[2], 'barrier points to paired content')
    F.ok(entries[2].paired_entry == entries[1], 'content points to paired barrier')
    F.eq(entries[1].input_policy, 'exclusive', 'barrier input is exclusive')
    F.eq(entries[2].input_policy, 'interactive', 'content input is independent')
    F.eq(entries[2].opaque, true, 'Page opaque metadata reaches content')

    local theatre = Theatre({ main = 'main', extension = 'extension' })
    theatre:push(route)
    local plan = theatre:plan()
    F.eq(#plan.entries, 4, 'route entries join stable Theatre entries')
    F.eq(plan.entries[3].kind, 'barrier', 'barrier is above Extension logically')
    F.eq(plan.entries[4].kind, 'popup', 'content is topmost logically')
    F.ok(plan.entries[3].input_active, 'barrier remains an input boundary')
    F.eq(plan.input_entries[1], route.content_entry, 'content is first input target')
    F.eq(plan.input_entries[2], route.barrier_entry, 'barrier follows content for input')

    route:mark_removed()
    F.eq(#theatre:entries(), 2, 'route removal removes barrier and content together')
    F.ok(route.content_entry.disposed, 'content entry is disposed')
    F.ok(route.barrier_entry.disposed, 'barrier entry is disposed')
    F.eq(route.lifecycle, 'disposed', 'PopupRoute uses Route disposal lifecycle')
end)

F.test('a dismissible ModalBarrier reports a logical dismissal without host input', function()
    local dismissed = nil
    local barrier = ModalBarrier({
        dismissible = true,
        on_dismiss = function(result)
            dismissed = result
        end,
    })
    F.ok(barrier:dismiss('outside'), 'dismissible barrier accepts activation')
    F.eq(dismissed, 'outside', 'barrier callback receives result')
    local blocked = ModalBarrier({ dismissible = false })
    F.ok(not blocked:dismiss(), 'non-dismissible barrier rejects activation')
end)

F.test('Navigator creates PopupRoute records without a second route protocol', function()
    local constraints_mod = require('layout.constraints')
    local render_owner_mod = require('render.render_owner')
    local binding_mod = require('widget.binding')
    local Navigator = navigation_mod.Navigator
    local Constraints = constraints_mod.Constraints
    local RenderOwner = render_owner_mod.RenderOwner
    local WidgetBinding = binding_mod.WidgetBinding
    local home = Page({ key = 'home', builder = function() return nil end })
    local popup = Page({
        key = 'popup',
        route_kind = 'popup',
        builder = function() return nil end,
    })
    local owner = RenderOwner()
    local binding = WidgetBinding(Navigator({ pages = { home, popup } }), owner)
    owner:set_viewport(Constraints.tight(400, 240))
    owner:layout()
    local state = binding.root_element.state
    F.ok(std.isinstance(state.routes[2], PopupRoute), 'popup page creates PopupRoute')
    F.ok(std.isinstance(state.routes[2], Route), 'popup route remains compatible with Route')
    binding:dispose()
end)
