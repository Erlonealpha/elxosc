-- Runtime identity, copied-owner isolation, and explicit shutdown.
---@diagnostic disable: undefined-field, inject-field, need-check-nil, param-type-mismatch
local F = require 'framework'
local support = require 'runtime_support'
local binding_mod = require 'widget.widgets_binding'
local scheduler_mod = require 'scheduler.scheduler'
local pipeline_mod = require 'render.pipeline_owner'
local key_mod = require 'widget.key'
local layout_mod = require 'widget.widgets.layout'
local WidgetsBinding = binding_mod.WidgetsBinding

F.section('runtime: shared Binding and independent owners')

F.test('two trees isolate dirty queues, clocks, keys and teardown', function()
    local clocks = { support.clock(), support.clock() }
    local schedulers = { scheduler_mod.Scheduler(clocks[1]), scheduler_mod.Scheduler(clocks[2]) }
    local key = key_mod.GlobalKey('shared-key')
    local first = support.mount(support.Probe({ key = key }), schedulers[1])
    local second = support.mount(support.Probe({ key = key }), schedulers[2])
    local binding = WidgetsBinding.instance()
    local states = { first.root_element.state, second.root_element.state }
    for index, tree in ipairs({ first, second }) do
        tree.on_dirty = function() schedulers[index]:schedule_frame() end
        schedulers[index]:add_persistent(function()
            tree:flush_build()
            tree.render_owner:flush_layout()
        end)
    end
    F.eq(first.binding, second.binding, 'shared composition')
    F.ok(first.root_element ~= second.root_element, 'independent root Elements')
    states[1]:set_state(function() states[1].value = 31 end)
    F.ok(first.build_owner:has_dirty(), 'first dirty')
    F.ok(not second.build_owner:has_dirty(), 'second clean')
    F.eq(clocks[1].requests, 1, 'first clock requested')
    F.eq(clocks[2].requests, 0, 'second clock untouched')
    clocks[1]:pump(1)
    F.eq(first.render_owner.root.size.width, 31, 'first output updated')
    F.eq(second.render_owner.root.size.width, 10, 'second output preserved')
    F.eq(states[2].builds, 1, 'second never rebuilt')
    first:dispose()
    schedulers[1]:dispose()
    F.eq(WidgetsBinding.instance(), binding, 'tree teardown keeps runtime')
    F.eq(key:current_state(), states[2], 'surviving owner remains queryable')
    states[2]:set_state(function() states[2].value = 42 end)
    clocks[2]:pump(2)
    F.eq(second.render_owner.root.size.width, 42, 'surviving tree still works')
    second:dispose()
    schedulers[2]:dispose()
    F.eq(key:current_state(), nil, 'last owner clears key')
end)

F.test('tree disposes owned PipelineOwner but leaves injected resources to caller', function()
    local owned = support.mount(support.Probe())
    owned.render_owner.on_dirty = function() end
    owned:dispose()
    F.eq(owned.render_owner.on_dirty, nil, 'internally created owner disposed')
    local clock = support.clock()
    local scheduler = scheduler_mod.Scheduler(clock)
    local owner = pipeline_mod.PipelineOwner()
    local callback = function() end
    owner.on_dirty = callback
    local tree = WidgetsBinding.ensure_initialized():attach(support.Probe(), owner, scheduler)
    tree:dispose()
    F.eq(owner.root, nil, 'injected owner detached')
    F.eq(owner.on_dirty, callback, 'injected owner remains caller owned')
    scheduler:schedule_frame()
    F.eq(clock.requests, 1, 'injected scheduler remains alive')
    owner:dispose()
    scheduler:dispose()
end)

F.test('runtime shutdown finalizes inactive trees and permits clean reinitialization', function()
    local key = key_mod.GlobalKey('shutdown')
    local tree = support.mount(support.Probe({ key = key }))
    local binding, state = tree.binding, tree.root_element.state
    tree.root_element:deactivate()
    F.ok(WidgetsBinding.shutdown(), 'runtime shutdown succeeds')
    F.eq(state.disposals, 1, 'inactive state disposed once')
    F.eq(key:current_element(), nil, 'shutdown clears registry')
    F.eq(WidgetsBinding.instance(), nil, 'singleton released')
    F.ok(not WidgetsBinding.shutdown(), 'second shutdown is a no-op')
    F.raises(function() binding:attach(layout_mod.SizedBox()) end,
        'disposed', 'old binding cannot resurrect')
    local fresh = WidgetsBinding.ensure_initialized()
    F.ok(fresh ~= binding, 'new runtime gets new composition')
end)

F.test('runtime shutdown continues after disposal failure and rejects reentrant attach', function()
    local first = support.mount(support.Probe({ on_dispose = function()
        WidgetsBinding.ensure_initialized():attach(layout_mod.SizedBox())
    end }))
    local second = support.mount(support.Probe())
    local first_state, second_state = first.root_element.state, second.root_element.state
    F.raises(function() WidgetsBinding.shutdown() end, 'disposed', 'closing runtime rejects attach')
    F.eq(first_state.disposals, 1, 'first State cleaned')
    F.eq(second_state.disposals, 1, 'other tree cleaned after failure')
    F.eq(first.render_owner.root, nil, 'first renderer released')
    F.eq(second.render_owner.root, nil, 'second renderer released')
    F.eq(WidgetsBinding.instance(), nil, 'failed shutdown still releases registry')
    WidgetsBinding.ensure_initialized()
end)
