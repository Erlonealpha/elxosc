-- The former manual lifecycle checklist, exercised on mounted State/Elements.
---@diagnostic disable: undefined-field, inject-field, need-check-nil, param-type-mismatch
local F = require 'framework'
local support = require 'runtime_support'
local layout_mod = require 'widget.widgets.layout'
local key_mod = require 'widget.key'
local navigation_mod = require 'widget.navigation'
local Probe = support.Probe
local SizedBox = layout_mod.SizedBox

F.section('runtime: lifecycle and illegal build boundaries')

F.test('init_state failure releases the root State resources and key', function()
    local key = key_mod.GlobalKey('failed-init')
    local released = 0
    F.raises(function()
        support.mount(Probe({ key = key, on_init = function(state)
            state:_own_resource({ dispose = function() released = released + 1 end })
            error('init failure')
        end }))
    end, 'init failure', 'initialization error propagated')
    F.eq(released, 1, 'partially initialized resources released')
    F.eq(key:current_element(), nil, 'partially initialized GlobalKey cleared')
end)

F.test('failed child reconciliation keeps old and new subtrees reachable for teardown', function()
    local keys = { key_mod.GlobalKey('old-a'), key_mod.GlobalKey('old-b'), key_mod.GlobalKey('new') }
    local tree = support.mount(layout_mod.Column({ children = {
        Probe({ key = keys[1] }), Probe({ key = keys[2] }),
    } }))
    local old_a, old_b = keys[1]:current_state(), keys[2]:current_state()
    F.raises(function()
        tree:set_root_widget(layout_mod.Column({ children = {
            Probe({ key = keys[3] }), Probe({ on_init = function() error('mount failed') end }),
        } }))
    end, 'mount failed', 'failed update reported')
    local new_state = keys[3]:current_state()
    tree:dispose()
    F.eq(old_a.disposals, 1, 'old a released')
    F.eq(old_b.disposals, 1, 'old b released')
    F.eq(new_state.disposals, 1, 'newly mounted State released')
    for _, key in ipairs(keys) do
        F.eq(key:current_state(), nil, 'no stale GlobalKey after failed reconciliation')
    end
end)

F.test('parent rebuild consumes a dirty child exactly once', function()
    local tree = support.mount(Probe({ on_build = function()
        return layout_mod.Column({ children = { Probe({ key = 'child' }) } })
    end }))
    local parent = tree.root_element.state
    local child = tree.root_element.child.children[1].state
    child:set_state(function() child.value = 17 end)
    parent:set_state()
    tree:flush_build()
    tree.render_owner:flush_layout()
    F.eq(parent.builds, 2, 'one parent build per update')
    F.eq(child.builds, 2, 'one child build despite both being dirty')
    F.eq(child.context:first_render_object().size.width, 17, 'child change reaches layout')
    F.ok(not tree.build_owner:has_dirty(), 'queue drained')
    tree:dispose()
end)

F.test('inactive reactivation preserves State and finalize disposes it once', function()
    local key = key_mod.GlobalKey('lifecycle')
    local tree = support.mount(Probe({ key = key }))
    local element = tree.root_element
    local state = element.state
    F.eq(key:current_state(), state, 'GlobalKey returns mounted State')
    state.value = 27
    element:deactivate()
    F.eq(key:current_state(), nil, 'inactive State is not current')
    element:activate(nil)
    tree:flush_build()
    F.eq(key:current_state(), state, 'reactivation keeps State identity')
    F.eq(state.value, 27, 'reactivation keeps data')
    F.eq(state.disposals, 0, 'reactivated element survives finalize')
    element:deactivate()
    tree:flush_build()
    tree:flush_build()
    F.eq(state.disposals, 1, 'unreactivated element disposed once')
    F.eq(key:current_element(), nil, 'registry cleared')
    F.eq(key:current_widget(), nil, 'widget lookup cleared')
    F.eq(key:current_context(), nil, 'context lookup cleared')
    F.eq(tree.render_owner.root, nil, 'finalized root stops rendering')
    tree:dispose()
    F.eq(state.disposals, 1, 'later tree disposal is idempotent')
end)

for _, operation in ipairs({ 'set_state', 'mark_dirty', 'rebuild', 'flush', 'root_update' }) do
    F.test('dispose rejects ' .. operation .. ' before mutating the tree', function()
        ---@type WidgetTree
        local tree
        local state
        local applied = false
        tree = support.mount(Probe({ on_dispose = function(current)
            state = current
            if operation == 'set_state' then
                current:set_state(function() applied = true end)
            elseif operation == 'mark_dirty' then
                current.context:mark_dirty()
            elseif operation == 'rebuild' then
                current.context:rebuild()
            elseif operation == 'flush' then
                tree.build_owner:rebuild_dirty()
            else
                tree:set_root_widget(SizedBox())
            end
        end }))
        -- Replacement exercises disposal while the surrounding tree is alive.
        F.raises(function()
            tree:set_root_widget(SizedBox({ key = 'replacement' }))
        end, 'locked during dispose', operation .. ' diagnostic')
        F.ok(not applied, 'State callback did not mutate')
        F.eq(state.builds, 1, 'no build during dispose')
        F.eq(state.context, nil, 'failed dispose still detaches State')
        F.ok(#tree.build_owner.diagnostics > 0, 'owner recorded lifecycle diagnostic')
        tree:set_root_widget(Probe())
        tree.root_element.state:set_state()
        tree:flush_build()
        F.eq(tree.root_element.state.builds, 2, 'lock released after failure')
        tree:dispose()
    end)
end

F.test('failed user disposal still releases resources and all children', function()
    local released = 0
    local keys = { key_mod.GlobalKey('a'), key_mod.GlobalKey('b') }
    local tree = support.mount(layout_mod.Column({ children = {
        Probe({ key = keys[1], on_dispose = function() error('dispose failure') end }),
        Probe({ key = keys[2] }),
    } }))
    local first, second = keys[1]:current_state(), keys[2]:current_state()
    first:_own_resource({ dispose = function() released = released + 1 end })
    first:_own_resource({ dispose = function() error('resource failure') end })
    F.raises(function() tree:dispose() end, 'dispose failure', 'original error preserved')
    F.eq(released, 1, 'later resource failure does not skip earlier resource')
    F.eq(second.disposals, 1, 'sibling disposed despite first failure')
    F.eq(keys[1]:current_state(), nil, 'first key cleared')
    F.eq(keys[2]:current_state(), nil, 'second key cleared')
    F.eq(tree.render_owner.root, nil, 'render root detached')
    F.ok(not tree:dispose(), 'repeat disposal has no side effects')
end)

F.test('direct recursive Element rebuild is diagnosed and recoverable', function()
    local recurse = false
    local tree = support.mount(Probe({ on_build = function(state)
        if recurse then
            state.context:rebuild()
        end
        return SizedBox()
    end }))
    recurse = true
    tree.root_element.state:set_state()
    F.raises(function() tree:flush_build() end, 'not reentrant', 'direct recursive rebuild')
    F.ok(not tree.build_owner:is_building(), 'owner build lock released')
    recurse = false
    tree.root_element.state:set_state()
    tree:flush_build()
    F.ok(not tree.build_owner:has_dirty(), 'later build succeeds')
    tree:dispose()
end)

F.test('Route result runs after content disposal and rebuilds surviving State before layout', function()
    local home_key, page_key = key_mod.GlobalKey('home'), key_mod.GlobalKey('page')
    local events = {}
    local tree = support.mount(navigation_mod.Navigator({ pages = {
        navigation_mod.Page({ key = 'home', builder = function()
            return Probe({ key = home_key })
        end }),
    } }))
    local navigator = tree.root_element.state
    local route = navigator:push(navigation_mod.Page({ key = 'details',
        builder = function()
            return Probe({ key = page_key, on_dispose = function()
                events[#events + 1] = 'content'
            end })
        end,
        on_pop = function() events[#events + 1] = 'pop' end,
        on_dispose = function() events[#events + 1] = 'route' end,
    }))
    tree:flush_build()
    local home = home_key:current_state()
    local builds = home.builds
    route.result:add_listener(function(value)
        F.eq(page_key:current_element(), nil, 'removed content and GlobalKey cleaned first')
        events[#events + 1] = 'result'
        home:set_state(function() home.value = value end)
    end)
    navigator:pop(55)
    tree:flush_build()
    F.eq(table.concat(events, ','), 'content,pop,result,route', 'dispose and result order')
    F.eq(home.value, 55, 'result listener may update surviving State')
    F.ok(home.builds > builds, 'result dirty is rebuilt in the same flush')
    F.ok(not tree.build_owner:has_dirty(), 'result leaves no unflushed build')
    tree:dispose()
end)
