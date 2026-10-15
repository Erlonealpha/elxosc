-- The mpv define host, with `mp` stubbed out.

-- `host/mpv_define.lua` requires `mp`; the suite replaces it with a tiny fake so
-- the window policy and the routing can be checked without mpv.
-- See the note in test_widget.lua: the `std.class` / optional-ownership
-- diagnostics are disabled across the suite.
---@diagnostic disable: undefined-field, inject-field, need-check-nil, generic-constraint-mismatch, preferred-local-alias, unused

local F = require('framework')
local std = require('elxlibs.std')

local text_layout = require('text.text_layout')
local constraints_mod = require('layout.constraints')
local render_owner = require('render.render_owner')
local binding_mod = require('widget.binding')
local bind_mod = require('widget.bind')
local player_context = require('widget.player_context')
local layout_widgets = require('widget.widgets.layout')
local basic_widgets = require('widget.widgets.basic')

local Constraints = constraints_mod.Constraints
local RenderOwner = render_owner.RenderOwner
local WidgetBinding = binding_mod.WidgetBinding
local Slot = bind_mod.Slot
local PlayerStore = player_context.PlayerStore
local Column = layout_widgets.Column
local Text = basic_widgets.Text

-- Deterministic measurer: half the font size per character (see test_widget.lua).
local FixedLayout = std.class.new('test.hostdefine.FixedLayout', { text_layout.TextLayout })
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
    return Column({ children = { Slot('slot'), root } })
end

---@param widget Widget
---@param binds BindRegistry
local function mount(widget, binds)
    local owner = RenderOwner()
    local binding = WidgetBinding(widget, owner, binds)
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
    local owner = mount(scaffold(Text('x')), define.binds)
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
    F.eq(define.session.phase, 'idle', 'nothing to seal')
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
