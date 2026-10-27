-- Slot composition identities must never become Widget reconciliation keys.
---@diagnostic disable: undefined-field, inject-field, need-check-nil, param-type-mismatch
local F = require 'framework'
local support = require 'runtime_support'
local slot_mod = require 'widget.slot'
local key_mod = require 'widget.key'
local layout_mod = require 'widget.widgets.layout'

F.section('runtime: Key identity through composition and reorder')

F.test('failed duplicate GlobalKey mount releases the partially mounted subtree', function()
    local key = key_mod.GlobalKey('duplicate-mount')
    local disposed = 0
    F.raises(function()
        support.mount(layout_mod.Column({ children = {
            support.Probe({ key = key, on_dispose = function() disposed = disposed + 1 end }),
            support.Probe({ key = key }),
        } }))
    end, 'already registered', 'duplicate mount is rejected')
    F.eq(disposed, 1, 'partially mounted State cleaned')
    F.eq(key:current_element(), nil, 'failed mount leaves no orphan registry')
    local tree = support.mount(support.Probe({ key = key }))
    F.eq(key:current_state(), tree.root_element.state, 'same key can mount successfully afterward')
    tree:dispose()
end)

F.test('key diagnostics retain readable names', function()
    F.contains(tostring(key_mod.ValueKey('row')), 'row', 'ValueKey describes its value')
    F.contains(tostring(key_mod.UniqueKey()), 'UniqueKey', 'UniqueKey diagnostic')
    F.contains(tostring(key_mod.ObjectKey({})), 'ObjectKey', 'ObjectKey diagnostic')
    F.contains(tostring(key_mod.GlobalKey('probe')), 'probe', 'GlobalKey debug label')
end)

F.test('LocalKey reorder preserves State and RenderObject identities', function()
    local function item(value)
        return support.Probe({ key = key_mod.ValueKey(value) })
    end
    local tree = support.mount(layout_mod.Column({ children = { item('a'), item('b') } }))
    local a, b = tree.root_element.children[1], tree.root_element.children[2]
    local renderer = a:first_render_object()
    a.state:set_state(function() a.state.value = 37 end)
    tree:flush_build()
    tree:set_root_widget(layout_mod.Column({ children = { item('b'), item('a') } }))
    tree.render_owner:flush_layout()
    F.eq(tree.root_element.children[1], b, 'b Element follows key')
    F.eq(tree.root_element.children[2], a, 'a Element follows key')
    F.eq(a:first_render_object(), renderer, 'RenderObject follows State')
    F.eq(renderer.size.width, 37, 'State data remains with a')
    F.eq(a.state.disposals, 0, 'reorder never disposes a')
    tree:dispose()
end)

F.test('append metadata orders Widgets without replacing their keys', function()
    local first_key, last_key = key_mod.GlobalKey('first'), key_mod.ValueKey('last')
    local first = support.Probe({ key = first_key })
    local last = support.Probe({ key = last_key })
    local registry = slot_mod.ContributionRegistry()
    registry:add('items', last, { op = 'append', name = 'metadata-last' }, 'scope')
    registry:add('items', first, { op = 'append', name = 'metadata-first', pos = 'first' }, 'scope')
    registry:add('items', support.Probe(), { op = 'append', key = 'forged' }, 'bad')
    local spec = slot_mod.SlotSpec({ id = 'items', default_op = 'append', allow = { 'append' },
        builder = function(children) return layout_mod.Column({ children = children }) end })
    local assembled, diagnostics = slot_mod.CompositionAssembler(registry:seal())
        :assemble(slot_mod.SlotWrap(spec))
    F.eq(#diagnostics, 1, 'forged append key diagnosed')
    F.eq(#assembled.children, 2, 'invalid contribution excluded')
    F.eq(assembled.children[1].key, first_key, 'GlobalKey identity survives fresh description')
    F.eq(assembled.children[2].key, last_key, 'LocalKey is not metadata identity')
    F.eq(first.key, first_key, 'caller key unchanged')
    local tree = support.mount(assembled)
    F.eq(first_key:current_state(), tree.root_element.children[1].state, 'key registered after assembly')
    tree:dispose()
    F.eq(first_key:current_state(), nil, 'assembled key cleared on disposal')
end)
