-- The mpv define host, with `mp` stubbed out.
---@namespace test.hostdefine

-- `host/mpv_define.lua` requires `mp`; the suite replaces it with a tiny fake so
-- the window policy and the routing can be checked without mpv.
-- See the note in test_widget.lua: the `std.class` / optional-ownership
-- diagnostics are disabled across the suite.generic-constraint-mismatch
---@diagnostic disable: undefined-field, inject-field, need-check-nil, preferred-local-alias, unused

local F = require('framework')
local std = require('elxlibs.std')

local text_layout = require('text.text_layout')
local constraints_mod = require('layout.constraints')
local render_owner = require('render.render_owner')
local binding_mod = require('widget.binding')
local slot_mod = require('widget.slot')
local player_context = require('widget.player_context')
local layout_widgets = require('widget.widgets.layout')
local basic_widgets = require('widget.widgets.basic')

local Constraints = constraints_mod.Constraints
local RenderOwner = render_owner.RenderOwner
local WidgetBinding = binding_mod.WidgetBinding
local SlotSpec = slot_mod.SlotSpec
local SlotWrap = slot_mod.SlotWrap
local PlayerStore = player_context.PlayerStore
local Column = layout_widgets.Column
local Text = basic_widgets.Text

-- Deterministic measurer: half the font size per character (see test_widget.lua).
---@class FixedLayout : TextLayout
---@overload fun(): self
local FixedLayout = std.class.new('FixedLayout', text_layout.TextLayout)
function FixedLayout:line_width(line, style)
    return #line * style.font_size * 0.5
end
text_layout.set_default(FixedLayout() --[[@as TextLayout]])

--== the `mp` fake =========================================================

local mp_stub = require('mp_stub')
mp_stub.install()

local fake = mp_stub.fake
local reset_fake = mp_stub.reset

reset_fake()

local mpv_define = require('host.mpv_define')
local MpDefine = mpv_define.MpDefine

---@param root Widget
---@return Widget
local function scaffold(root)
    return Column({ children = {
        SlotWrap(SlotSpec({ id = 'slot', allow = { 'set' }, default_op = 'set' })),
        root,
    } })
end

---@param widget Widget
local function mount(widget)
    local owner = RenderOwner()
    local binding = WidgetBinding.ensure_initialized():attach(widget, owner)
    owner:set_viewport(Constraints.loose(1000, 1000))
    owner:layout()
    return owner, binding
end

---@return table<string, function> log
local function dispatcher()
    ---@type table<string, function>
    local log = {}
    for name, cb in pairs(fake.log) do
        if name == 'define_start' or name == 'define' or name == 'define_end' then
            log[name] = cb
        end
    end
    F.ok(log.define_start ~= nil, 'define_start registered')
    F.ok(log.define ~= nil, 'define registered')
    F.ok(log.define_end ~= nil, 'define_end registered')
    return log
end

--== the `mp` module =======================================================

F.section('host define: the mp module')

F.test('the module exposes props and is protected', function()
    reset_fake()
    local define = MpDefine()
    local mp_env = {}
    define.session.modules:import_into('mp', mp_env, 'scope_a')
    F.eq(mp_env.get_prop('pause'), 'native:pause', 'data module flattened')
    F.ok(mp_env.set_prop ~= nil, 'set_prop')
    F.eq(define.session.modules:is_protected('mp'), true, 'script cannot replace it')
end)

F.test('the loader installs scope-specific on_message / emit', function()
    reset_fake()
    local define = MpDefine()
    local mp_env = {}
    define.session.modules:import_into('mp', mp_env, 'scope_a')
    mp_env.on_message(function() end)
    F.ok(fake.log['scope_a'] ~= nil, 'messages for the scope id are routed')
    mp_env.emit('hello', 'world')
    F.eq(fake.commands[1][1], 'script-message', 'emit uses script-message')
    F.eq(fake.commands[1][2], 'scope_a', 'addressed to the scope')
end)

F.test('on_prop forwards to mp.observe_property', function()
    reset_fake()
    local define = MpDefine()
    local mp_env = {}
    define.session.modules:import_into('mp', mp_env, 'scope_a')
    mp_env.on_prop('pause', function() end)
    F.eq(#fake.events, 1, 'observed once')
    F.eq(fake.events[1].name, 'pause', 'the requested property')
end)

F.test('on_prop returns a disposable observer', function()
    reset_fake()
    local define = MpDefine()
    local mp_env = {}
    define.session.modules:import_into('mp', mp_env, 'scope_a')
    local callback = function() end
    local subscription = mp_env.on_prop('pause', callback)
    F.ok(subscription:is_active(), 'observer starts active')
    F.ok(subscription:dispose(), 'observer disposes')
    F.ok(not subscription:dispose(), 'observer disposal is idempotent')
    F.eq(fake.unobserved[1], callback, 'the original callback is unobserved')
end)

F.test('on_event returns a disposable observer', function()
    reset_fake()
    local define = MpDefine()
    local mp_env = {}
    define.session.modules:import_into('mp', mp_env, 'scope_a')
    local subscription = mp_env.on_event('file-loaded', function() end)
    F.ok(subscription:is_active(), 'event observer starts active')
    F.ok(subscription:dispose(), 'event observer disposes')
    F.ok(not subscription:dispose(), 'event disposal is idempotent')
end)

F.section('host define: player module')

F.test('player module exposes read-only snapshots and subscriptions', function()
    reset_fake()
    local store = PlayerStore({ value = 1 })
    local define = MpDefine({ player_store = store })
    local player_env = {}
    define.session.modules:import_into('player', player_env, 'scope_a')

    F.eq(player_env.get_snapshot().value, 1, 'current snapshot is readable')
    local updates = 0
    local subscription = player_env.on_update(function(snapshot, previous)
        updates = updates + snapshot.value - previous.value
    end)
    store:replace({ value = 3 })
    F.eq(updates, 2, 'subscription receives store updates')
    subscription:dispose()
    store:replace({ value = 4 })
    F.eq(updates, 2, 'disposed subscription is silent')
end)

--== the window ============================================================

F.test('player import exposes explicit component identities and constructs Define content', function()
    reset_fake()
    local define = MpDefine({ builtins = {} })
    local exports = require('widget.player.exports').exports
    local env = {}
    define.session.modules:import_into('player', env, 'extension')
    for name, value in pairs(exports) do
        F.eq(env[name], value, 'player export identity: ' .. name)
    end
    F.eq(env.geometry_for, nil, 'internal geometry is excluded')
    F.eq(env.default_controller, nil, 'internal assembly helper is excluded')
    F.eq(env.PlayerStore, nil, 'host store mutation is not exported')
    F.raises(function()
        define.session.modules:publish('player', {})
    end, 'protected', 'player module remains protected')
    define:listen()
    local log = dispatcher()
    log.define_start()
    log.define('extension', [[
        import('player')
        button = PlayerControlButton({ icon = 'toggle_on' })
        bind('slot', PlayerTooltip({ text = 'extension', child = button }))
    ]])
    log.define_end()
    local owner, tree = mount(define:assemble(scaffold(Text('root'))))
    F.ok(owner.root ~= nil, 'imported controls mount through Define')
    F.eq(define.session:env_for('extension').button.__class, exports.PlayerControlButton,
        'Define uses the canonical class')
    tree:dispose()
    define:shutdown()
end)

F.test('host collects standard packages and keeps builtins independent of registry additions', function()
    reset_fake()
    local define = MpDefine({ builtins = {} })
    for _, package in ipairs(require('libs.exports').collect()) do
        F.ok(define.session.modules:is_protected(package.name), 'protected package: ' .. package.name)
        if package.name ~= 'player' then
            F.eq(define.session.modules:get(package.name), package.exports,
                'canonical export table: ' .. package.name)
        end
    end
    F.eq(define.session.api.Text, nil, 'empty builtins override does not implicitly expose packages')
    define.session.modules:add('additional', { accidental_global = 42 })
    F.eq(define.session.api.accidental_global, nil, 'new module does not expand builtins')
    define:shutdown()
end)

F.test('flattened standard widget import preserves the Define bind protocol', function()
    reset_fake()
    local define = MpDefine({ builtins = {} })
    define.session:define_start()
    define.session:define('widgets', [[
        import('widget')
        bind('slot', Text('standard package'))
    ]])
    local env = define.session:env_for('widgets')
    F.eq(env.bind, define.session.api.bind, 'scope-aware bind remains available')
    F.eq(env.Text, Text, 'standard package keeps canonical constructors')
    define.session:define_end()
    local owner, tree = mount(define:assemble(scaffold(Text('root'))))
    F.ok(owner.root ~= nil, 'imported standard widgets mount through Define')
    tree:dispose()
    define:shutdown()
end)

F.test('import_as mp and player keep scope names local and owned subscriptions are cleaned', function()
    reset_fake()
    local store = PlayerStore({ value = 1 })
    local define = MpDefine({ builtins = {}, player_store = store })
    define:listen()
    local log = dispatcher()
    log.define_start()
    log.define('namespaced', [[
        host = import_as('mp')
        player_api = import_as('player')
        host.on_prop('pause', function() end)
        host.on_message(function() end)
        updated = 0
        player_api.on_update(function() updated = updated + 1 end)
        current = player_api.get_snapshot().value
    ]])
    local env = define.session:env_for('namespaced')
    F.eq(env.get_prop, nil, 'mp names are not injected')
    F.eq(env.on_message, nil, 'loader names are not injected')
    F.eq(env.Timeline, nil, 'player names are not injected')
    F.eq(env.current, 1, 'player snapshot through namespaced package')
    F.ok(fake.log.namespaced ~= nil, 'scope message callback installed')
    store:replace({ value = 2 })
    F.eq(env.updated, 1, 'subscription receives updates')
    define:shutdown()
    F.eq(#fake.unobserved, 1, 'mp observer released')
    F.eq(fake.log.namespaced, nil, 'scope message callback released')
    store:replace({ value = 3 })
    F.eq(env.updated, 1, 'player subscription released')
end)

F.section('host define: the window')

F.test('define_start / define / define_end seal through the messages', function()
    reset_fake()
    local define = MpDefine({ builtins = { Text = Text } })
    define:listen()
    local log = dispatcher()
    local sealed = 0
    define.on_sealed = function() sealed = sealed + 1 end

    log.define_start()
    log.define('scope_a', "bind('slot', Text('hi'))")
    log.define_end()

    F.eq(define:is_sealed(), true, 'sealed')
    F.eq(sealed, 1, 'on_sealed fired')
    local assembled = define:assemble(scaffold(Text('x')))
    local owner = mount(assembled)
    F.eq(owner.root:children()[1].paragraph.text, 'hi', 'the bind landed')
end)

F.test('refcounted: one define_end does not seal two starters', function()
    reset_fake()
    local define = MpDefine()
    define:listen()
    local log = dispatcher()
    log.define_start()
    log.define_start()
    log.define_end()
    F.eq(define:is_sealed(), false, 'one starter is still open')
    log.define_end()
    F.eq(define:is_sealed(), true, 'both ended')
end)

F.test('define without define_start is ignored', function()
    reset_fake()
    local define = MpDefine()
    define:listen()
    local log = dispatcher()
    log.define('scope_a', 'x = 1')
    F.eq(define.session:env_for('scope_a').x, nil, 'the payload did not run')
end)

F.test('close seals and stops listening', function()
    reset_fake()
    local define = MpDefine()
    define:listen()
    dispatcher()
    -- a starter that never ended
    fake.log['define_start']()
    define:close()
    F.eq(define:is_sealed(), true, 'sealed despite the missing define_end')
    F.eq(fake.log['define'], nil, 'the handlers were unregistered')
end)

F.test('close is idempotent when the session is idle', function()
    reset_fake()
    local define = MpDefine()
    define:listen()
    define:close()
    define:close()
    F.eq(define.session.phase, 'sealed', 'idle close seals the session')
end)

F.test('shutdown disposes Define-owned host observers', function()
    reset_fake()
    local define = MpDefine()
    local mp_env = {}
    define.session.modules:import_into('mp', mp_env, 'scope_a')
    local subscription = mp_env.on_prop('pause', function() end)
    F.ok(subscription:is_active(), 'observer is active before shutdown')
    F.ok(define:shutdown(), 'shutdown runs once')
    F.ok(not subscription:is_active(), 'observer is disposed by shutdown')
    F.ok(not define:shutdown(), 'shutdown is idempotent')
end)

F.test('a broken payload is logged, not raised', function()
    reset_fake()
    local define = MpDefine()
    define:listen()
    local log = dispatcher()
    log.define_start()
    log.define('scope_a', 'this is not lua')
    local logged = false
    for _, entry in ipairs(fake.messages) do
        if entry[1] == 'error' then logged = true end
    end
    F.eq(logged, true, 'reported through mp.msg.error')
    F.eq(define.session.phase, 'defining', 'the window stays open for the others')
end)

F.test('failed payloads dispose host subscriptions created during staging', function()
    reset_fake()
    local define = MpDefine()
    define:listen()
    local log = dispatcher()
    log.define_start()
    log.define('scope_a', [[
        import('mp')
        subscription = on_prop('pause', function() end)
        missing_call()
    ]])
    F.eq(#fake.unobserved, 1, 'staged property observer is rolled back')
    F.ok(define.session:env_for('scope_a').subscription == nil,
        'failed payload does not publish the subscription')
end)
