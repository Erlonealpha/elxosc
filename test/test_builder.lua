-- P1 Builder contracts: semantic callback boundaries, validation and cleanup.
---@namespace test.builder
---@diagnostic disable: undefined-field, inject-field, need-check-nil, unused, param-type-mismatch, return-type-mismatch

local F = require 'framework'
local std = require 'elxlibs.std'
local support = require 'runtime_support'
local text_layout = require 'text.text_layout'

local widget_api = require 'widget'
local builder_mod = require 'widget.builder'
local widget_mod = require 'widget.widget'
local state_mod = require 'widget.state'
local key_mod = require 'widget.key'
local basic_widgets = require 'widget.widgets.basic'
local overlay_mod = require 'widget.overlay'
local navigation_mod = require 'widget.navigation'
local slot_mod = require 'widget.slot'

local StatelessWidget = widget_mod.StatelessWidget
local StatefulWidget = widget_mod.StatefulWidget
local State = state_mod.State
local GlobalKey = key_mod.GlobalKey
local Text = basic_widgets.Text
local Overlay = overlay_mod.Overlay
local OverlayEntry = overlay_mod.OverlayEntry
local Page = navigation_mod.Page
local Navigator = navigation_mod.Navigator
local SlotSpec = slot_mod.SlotSpec
local SlotWrap = slot_mod.SlotWrap
local CompositionAssembler = slot_mod.CompositionAssembler

---@class FixedLayout : TextLayout
---@overload fun(): self
local FixedLayout = std.class.new('FixedLayout', text_layout.TextLayout)
function FixedLayout:line_width(line, style)
    return #line * style.font_size * 0.5
end
text_layout.set_default(FixedLayout())

F.section('builder: public contract')

F.test('builder helpers preserve direct and aggregate module identity', function()
    F.eq(widget_api.call_context, builder_mod.call_context, 'context helper identity')
    F.eq(widget_api.call_slot, builder_mod.call_slot, 'slot helper identity')
    F.eq(widget_api.validate_context, builder_mod.validate_context, 'context validator identity')
    F.eq(widget_api.validate_result, builder_mod.validate_result, 'result validator identity')
end)

F.test('context builders require an active mounted context', function()
    local unmounted = Text('unmounted'):create_element()
    F.raises(function()
        builder_mod.call_context(function()
            return Text('bad')
        end, unmounted, 'Test.context_builder')
    end, 'mounted BuildContext', 'unmounted context is rejected')

    F.raises(function()
        builder_mod.call_context(function()
            return Text('bad')
        end, {}, 'Test.context_builder')
    end, 'mounted BuildContext', 'non-Element context is rejected')
end)

F.test('slot builders run before mounting and are not rerun by the mounted tree', function()
    local calls = 0
    local value = Text('slot')
    local spec = SlotSpec({
        id = 'builder-contract',
        allow = { 'set' },
        default_op = 'set',
        builder = function(next_value, opts)
            calls = calls + 1
            F.ok(type(opts) == 'table', 'Slot builder receives normalized opts')
            return next_value
        end,
    })
    local assembled = CompositionAssembler():assemble(SlotWrap(spec, value))
    F.eq(calls, 1, 'Slot builder runs during assembly')
    local tree = support.mount(assembled)
    tree:flush_build()
    F.eq(calls, 1, 'mounted rebuilds do not rerun Slot assembly')
    tree:dispose()
end)

F.test('all builder result boundaries reject non-Widgets with named errors', function()
    local spec = SlotSpec({
        id = 'invalid-slot-builder',
        allow = { 'set' },
        default_op = 'set',
        builder = function()
            return 'not a Widget'
        end,
    })
    F.raises(function()
        spec:build(nil, {})
    end, 'SlotSpec', 'Slot builder validates its result')

    local page = Page({
        key = 'invalid-page-builder',
        builder = function()
            return 'not a Widget'
        end,
    })
    F.raises(function()
        support.mount(Navigator({ pages = { page } }))
    end, 'Page.builder', 'Page builder validates its result')

    local entry = OverlayEntry({
        builder = function()
            return 'not a Widget'
        end,
    })
    F.raises(function()
        support.mount(Overlay({ initial_entries = { entry } }))
    end, 'OverlayEntry.builder', 'Overlay builder validates its result')
end)

---@class _BadStatelessOptions
---@field key? any

---@class BadStateless : StatelessWidget
---@overload fun(options: _BadStatelessOptions?): self
local BadStateless = std.class.new('BadStateless', StatelessWidget)
function BadStateless:__init(options)
    self.key = options and options.key
end
function BadStateless:build()
    return 'not a Widget'
end

---@class BadState : State
---@overload fun(): self
local BadState = std.class.new('BadState', State)
function BadState:build()
    return false
end

---@class _BadStatefulOptions
---@field key? any

---@class BadStateful : StatefulWidget
---@overload fun(options: _BadStatefulOptions?): self
local BadStateful = std.class.new('BadStateful', StatefulWidget)
function BadStateful:__init(options)
    self.key = options and options.key
end
function BadStateful:create_state()
    return BadState()
end

F.test('StatelessWidget and State build results use the same validation boundary', function()
    local stateless_key = GlobalKey('bad-stateless-builder')
    F.raises(function()
        support.mount(BadStateless({ key = stateless_key }))
    end, 'StatelessWidget.build', 'StatelessWidget build error is named')
    F.eq(stateless_key:current_element(), nil, 'failed stateless mount cleans its key')

    local stateful_key = GlobalKey('bad-state-builder')
    F.raises(function()
        support.mount(BadStateful({ key = stateful_key }))
    end, 'State.build', 'State build error is named')
    F.eq(stateful_key:current_element(), nil, 'failed state mount cleans its key')
end)

---@class _ThrowingBuilderOptions
---@field key? any

---@class ThrowingBuilder : StatelessWidget
---@overload fun(options: _ThrowingBuilderOptions?): self
local ThrowingBuilder = std.class.new('ThrowingBuilder', StatelessWidget)
function ThrowingBuilder:__init(options)
    self.key = options and options.key
end
function ThrowingBuilder:build()
    error('builder failure is preserved')
end

F.test('builder exceptions preserve the original error and clean partial mounts', function()
    local key = GlobalKey('throwing-builder')
    F.raises(function()
        support.mount(ThrowingBuilder({ key = key }))
    end, 'builder failure is preserved', 'original builder error is surfaced')
    F.eq(key:current_element(), nil, 'failed builder mount leaves no key registry entry')
end)

---@class _StableChildOptions
---@field key? any

---@class StableChild : StatelessWidget
---@overload fun(options: _StableChildOptions?): self
local StableChild = std.class.new('StableChild', StatelessWidget)
function StableChild:__init(options)
    self.key = options and options.key
end
function StableChild:build()
    return Text('stable child')
end

---@class _RebuildHostOptions
---@field key? any
---@field fail? boolean
---@field child_key? any

---@class RebuildHost : StatelessWidget
---@field fail boolean
---@field child_key? any
---@overload fun(options: _RebuildHostOptions?): self
local RebuildHost = std.class.new('RebuildHost', StatelessWidget)
function RebuildHost:__init(options)
    self.key = options and options.key
    self.fail = options and options.fail == true
    self.child_key = options and options.child_key
end
function RebuildHost:build()
    if self.fail then
        error('builder failure during rebuild')
    end
    return StableChild({ key = self.child_key })
end

F.test('a failed rebuild keeps the old child reachable and recoverable', function()
    local child_key = GlobalKey('rebuild-child')
    local tree = support.mount(RebuildHost({ key = 'host', child_key = child_key }))
    local old_child = child_key:current_element()
    F.ok(old_child ~= nil, 'initial builder child mounted')

    F.raises(function()
        tree:set_root_widget(RebuildHost({ key = 'host', fail = true, child_key = child_key }))
    end, 'builder failure during rebuild', 'rebuild builder error is surfaced')
    F.eq(child_key:current_element(), old_child, 'failed rebuild retains old child')

    tree:set_root_widget(RebuildHost({ key = 'host', child_key = child_key }))
    F.eq(child_key:current_element(), old_child, 'failed rebuild can recover')
    tree:dispose()
    F.eq(child_key:current_element(), nil, 'recovered tree disposes normally')
end)

F.test('coalesced entry invalidation performs one builder call per flush', function()
    local builds = 0
    local entry = OverlayEntry({
        builder = function(context)
            F.ok(context:is_active(), 'entry builder context is active')
            builds = builds + 1
            return Text('entry')
        end,
    })
    local tree = support.mount(Overlay({ initial_entries = { entry } }))
    local initial = builds
    entry:mark_needs_build()
    entry:mark_needs_build()
    tree:flush_build()
    F.eq(builds, initial + 1, 'duplicate invalidation is coalesced')
    tree:dispose()
end)
