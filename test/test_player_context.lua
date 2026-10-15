-- Provider and host-independent player context values/stores.

---@diagnostic disable: undefined-field, inject-field, need-check-nil, generic-constraint-mismatch, preferred-local-alias, unused, call-non-callable

local F = require('framework')
local std = require('elxlibs.std')

local constraints_mod = require('layout.constraints')
local render_owner = require('render.render_owner')
local text_layout = require('text.text_layout')
local widget_mod = require('widget.widget')
local binding_mod = require('widget.binding')
local provider_mod = require('widget.provider')
local player_context = require('widget.player_context')

local Constraints = constraints_mod.Constraints
local RenderOwner = render_owner.RenderOwner
local WidgetBinding = binding_mod.WidgetBinding
local StatelessWidget = widget_mod.StatelessWidget
local Text = require('widget.widgets.basic').Text
local Provider = provider_mod.Provider
local PlayerSnapshot = player_context.PlayerSnapshot
local PlayerStore = player_context.PlayerStore
local PlayerProvider = player_context.PlayerProvider
local PlayerScope = player_context.PlayerScope

local FixedLayout = std.class.new('test.PlayerContextLayout', { text_layout.TextLayout })
function FixedLayout:line_width(line, style)
    return #line * style.font_size * 0.5
end
text_layout.set_default(FixedLayout())

local function mount(widget)
    local owner = RenderOwner()
    local binding = WidgetBinding(widget, owner)
    owner:set_viewport(Constraints.loose(1000, 1000))
    owner:layout()
    return owner, binding
end

local Reader = std.class.new('test.PlayerContextReader', { StatelessWidget })
function Reader:build(context)
    local provider = PlayerProvider.of(context)
    return Text('value=' .. tostring(provider.snapshot.value))
end

local MaybeReader = std.class.new('test.PlayerContextMaybeReader', { StatelessWidget })
function MaybeReader:build(context)
    local provider = PlayerProvider.maybe_of(context)
    return Text(provider and 'provided' or 'missing')
end

F.section('player context: provider lookup')

F.test('the widget aggregate preserves context class identity', function()
    local api = require('widget')
    F.ok(api.Provider == Provider, 'Provider identity')
    F.ok(api.PlayerSnapshot == PlayerSnapshot, 'PlayerSnapshot identity')
    F.ok(api.PlayerStore == PlayerStore, 'PlayerStore identity')
    F.ok(api.PlayerProvider == PlayerProvider, 'PlayerProvider identity')
    F.ok(api.PlayerScope == PlayerScope, 'PlayerScope identity')
end)

F.test('Provider of and maybe_of use the inherited dependency lookup', function()
    local snapshot = PlayerSnapshot({ value = 1 })
    local owner, binding = mount(PlayerProvider({
        snapshot = snapshot,
        child = MaybeReader(),
    }))
    local inherited = PlayerProvider.of(binding.root_element.child)
    F.eq(inherited.snapshot.value, snapshot.value, 'PlayerProvider.of returns the ancestor')
    F.eq(owner.root.paragraph.text, 'provided', 'maybe_of sees the ancestor')
end)

F.test('maybe_of returns nil outside a provider', function()
    local owner, binding = mount(MaybeReader())
    F.ok(PlayerProvider.maybe_of(binding.root_element) == nil, 'missing provider is nil')
    F.eq(owner.root.paragraph.text, 'missing', 'descendant handles the missing provider')
end)

F.test('Provider.of can query a concrete inherited Provider class', function()
    local Marker = std.class.new('test.MarkerProvider', { Provider })
    function Marker:__init(options)
        options = options or {}
        self.key = options.key
        self.child = options.child
        self.value = options.value
    end

    local ShowMarker = std.class.new('test.ShowMarker', { StatelessWidget })
    function ShowMarker:build(context)
        local marker = Provider.of(context, Marker --[[@as std.Class]])
        return Text(marker.value)
    end

    local owner = mount(Marker({ value = 'marker', child = ShowMarker() }))
    F.eq(owner.root.paragraph.text, 'marker', 'concrete Provider lookup')
end)

F.test('replacing a Provider notifies registered dependents', function()
    local owner, binding = mount(PlayerProvider({
        snapshot = PlayerSnapshot({ value = 1 }),
        child = Reader(),
    }))
    binding:set_root_widget(PlayerProvider({
        snapshot = PlayerSnapshot({ value = 2 }),
        child = Reader(),
    }))
    binding:flush_build()
    owner:layout()
    F.eq(owner.root.paragraph.text, 'value=2', 'dependent rebuilt with the replacement')
end)

F.section('player context: snapshots')

F.test('PlayerSnapshot copies caller fields and nested tables', function()
    local fields = {
        value = 1,
        metadata = { enabled = true },
    }
    local snapshot = PlayerSnapshot(fields)
    fields.value = 2
    fields.metadata.enabled = false
    fields.added = true

    F.eq(snapshot.value, 1, 'scalar input is isolated')
    F.ok(snapshot.metadata.enabled, 'nested input is isolated')
    F.ok(snapshot.added == nil, 'later input fields are not visible')
end)

F.test('PlayerSnapshot copy applies independent overrides', function()
    local snapshot = PlayerSnapshot({ value = 1, title = 'old' })
    local overrides = { value = 2 }
    local copy = snapshot:copy(overrides)
    overrides.value = 3

    F.eq(snapshot.value, 1, 'copy leaves the original unchanged')
    F.eq(copy.value, 2, 'copy applies the override')
    F.eq(copy.title, 'old', 'copy retains other fields')
    F.eq(copy:to_table().value, 2, 'to_table returns the copied value')
end)

F.test('Store consumers receive read-only snapshot views', function()
    local store = PlayerStore({ value = 1, metadata = { enabled = true } })
    local snapshot = store:get()
    F.raises(function()
        snapshot.value = 2
    end, 'RuntimeError', 'scalar snapshot field is read-only')
    F.raises(function()
        snapshot.metadata.enabled = false
    end, 'RuntimeError', 'nested snapshot field is read-only')
    local copy = snapshot:to_table()
    copy.metadata.enabled = false
    F.ok(store:get().metadata.enabled, 'mutable copies do not alter the store')
end)

F.test('PlayerSnapshot rejects invalid data at its boundary', function()
    F.raises(function()
        PlayerSnapshot('not a table' --[[@as _PlayerSnapshotOptions]])
    end, 'TypeError', 'non-table snapshot')
    F.raises(function()
        PlayerSnapshot({ value = math.huge })
    end, 'ValueError', 'non-finite snapshot value')
    local cyclic = {}
    cyclic.self = cyclic
    F.raises(function()
        PlayerSnapshot({ data = cyclic })
    end, 'ValueError', 'cyclic snapshot value')
end)

F.section('player context: store')

F.test('PlayerStore notifies active subscribers in registration order', function()
    local store = PlayerStore(PlayerSnapshot({ value = 0 }))
    local order = {}
    local first = store:subscribe(function(snapshot, previous)
        order[#order + 1] = 'first:' .. snapshot.value .. ':' .. previous.value
    end)
    local second = store:subscribe(function(snapshot)
        order[#order + 1] = 'second:' .. snapshot.value
    end)

    F.ok(store:get().value == 0, 'get returns the current snapshot')
    store:replace(PlayerSnapshot({ value = 1 }))
    F.eq(order[1], 'first:1:0', 'first listener runs first')
    F.eq(order[2], 'second:1', 'second listener runs second')

    F.ok(first:is_active() and second:is_active(), 'subscriptions start active')
end)

F.test('PlayerStore rejects invalid non-nil initial values', function()
    F.raises(function()
        PlayerStore(false --[[@as PlayerSnapshot]])
    end, 'TypeError', 'boolean initial snapshot')
    F.raises(function()
        PlayerStore(0 --[[@as PlayerSnapshot]])
    end, 'TypeError', 'number initial snapshot')
end)

F.test('disposed subscriptions are idempotent and are not notified', function()
    local store = PlayerStore({ value = 0 })
    local calls = 0
    local subscription = store:subscribe(function()
        calls = calls + 1
    end)
    F.ok(subscription:dispose(), 'first dispose reports disposal')
    F.ok(not subscription:dispose(), 'second dispose is a no-op')
    store:replace({ value = 1 })
    F.eq(calls, 0, 'disposed listener is skipped')
    F.ok(not subscription:is_active(), 'subscription stays inactive')
end)

F.test('disposed subscriptions are removed from the Store', function()
    local store = PlayerStore()
    for _ = 1, 20 do
        store:subscribe(function() end):dispose()
    end
    F.eq(#store._subscriptions, 0, 'disposed subscriptions do not accumulate')
end)

F.test('subscriber errors do not prevent later subscribers', function()
    local errors = 0
    local calls = 0
    local store = PlayerStore({ value = 0 }, {
        on_error = function() errors = errors + 1 end,
    })
    store:subscribe(function()
        error('listener failed')
    end)
    store:subscribe(function()
        calls = calls + 1
    end)
    store:replace({ value = 1 })
    F.eq(errors, 1, 'subscriber error is reported')
    F.eq(calls, 1, 'later subscribers still receive the update')
end)

F.section('player context: scope lifecycle')

F.test('PlayerScope connects Store updates to State and descendants', function()
    local store = PlayerStore({ value = 1 })
    local owner, binding = mount(PlayerScope({
        store = store,
        child = Reader(),
    }))
    local state = binding.root_element.state
    F.eq(owner.root.paragraph.text, 'value=1', 'scope exposes its initial snapshot')

    store:replace({ value = 2 })
    F.ok(binding.build_owner:has_dirty(), 'Store update marks the scope State dirty')
    binding:flush_build()
    owner:layout()
    F.eq(owner.root.paragraph.text, 'value=2', 'descendant receives the new snapshot')
    F.ok(state.subscription and state.subscription:is_active(), 'scope owns its subscription')
end)

F.test('PlayerScope disposes its Store subscription when unmounted', function()
    local store = PlayerStore({ value = 1 })
    local owner, binding = mount(PlayerScope({
        store = store,
        child = Reader(),
    }))
    local state = binding.root_element.state
    binding:set_root_widget(Text('gone'))
    owner:layout()
    F.ok(state.subscription == nil, 'scope cleared its subscription')

    store:replace({ value = 2 })
    F.ok(not binding.build_owner:has_dirty(), 'unmounted scope is not dirtied')
    F.eq(owner.root.paragraph.text, 'gone', 'unmounted tree remains detached')
end)

F.test('unmounted Provider dependents are removed immediately', function()
    local owner, binding = mount(PlayerProvider({
        snapshot = PlayerSnapshot({ value = 1 }),
        child = Reader(),
    }))
    local provider_element = binding.root_element
    F.eq(next(provider_element.dependents) ~= nil, true, 'reader registered as dependent')

    binding:set_root_widget(PlayerProvider({
        snapshot = PlayerSnapshot({ value = 2 }),
        child = Text('plain'),
    }))
    binding:flush_build()
    owner:layout()
    F.eq(next(provider_element.dependents), nil, 'unmounted reader was removed')
end)
