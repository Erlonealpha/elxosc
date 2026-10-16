-- Definition sandbox: the env primitives, the module registry and the define
-- protocol. The framework owns none of the host services here — the `mp` module
-- below is built exactly the way a real host would build it.

-- See the note in test_widget.lua: the `std.class` / optional-ownership
-- diagnostics are disabled across the suite.
---@diagnostic disable: undefined-field, inject-field, need-check-nil, generic-constraint-mismatch, preferred-local-alias, unused

local F = require('framework')
local std = require('elxlibs.std')

local sandbox = require('libs.sandbox')
local modules_mod = require('libs.modules')
local define_mod = require('libs.define')

local text_layout = require('text.text_layout')
local constraints_mod = require('layout.constraints')
local render_owner = require('render.render_owner')
local binding_mod = require('widget.binding')
local bind_mod = require('widget.bind')
local layout_widgets = require('widget.widgets.layout')
local basic_widgets = require('widget.widgets.basic')

local ModuleRegistry = modules_mod.ModuleRegistry
local DefineSession = define_mod.DefineSession
local Constraints = constraints_mod.Constraints
local RenderOwner = render_owner.RenderOwner
local WidgetBinding = binding_mod.WidgetBinding
local Slot = bind_mod.Slot
local Column = layout_widgets.Column
local Text = basic_widgets.Text

-- Deterministic measurer: half the font size per character (see test_widget.lua).
local FixedLayout = std.class.new('test.define.FixedLayout', { text_layout.TextLayout })
function FixedLayout:line_width(line, style)
    return #line * style.font_size * 0.5
end
text_layout.set_default(FixedLayout() --[[@as TextLayout]])

---@param widget Widget
---@param binds BindRegistry?
local function mount(widget, binds)
    local owner = RenderOwner()
    local binding = WidgetBinding(widget, owner, binds)
    owner:set_viewport(Constraints.loose(1000, 1000))
    owner:layout()
    return owner, binding
end

--== environment primitives ================================================

F.section('define: environment')

F.test('reads fall through to the api, writes stay in the env', function()
    local env = sandbox.new_env({ marker = 'host' })
    F.eq(env.marker, 'host', 'api value visible')
    env.answer = 41
    env.answer = env.answer + 1
    F.eq(env.answer, 42, 'written into the env itself')
    F.eq(rawget(env, 'marker'), nil, 'api names are not copied in')
end)

F.test('a chunk runs against the env, not the globals', function()
    local env = sandbox.new_env({ marker = 'host' })
    local chunk = sandbox.load_chunk('result = marker\nleak = 1', '@t', env)
    F.ok(chunk ~= nil, 'compiled')
    chunk()
    F.eq(env.result, 'host', 'chunk saw the api')
    F.eq(rawget(_G, 'leak'), nil, 'nothing escaped into _G')
end)

F.test('standard globals are not reachable', function()
    local env = sandbox.new_env({})
    F.eq(sandbox.load_chunk('return string', '@t', env)(), nil, 'no string library')
    F.eq(sandbox.load_chunk('return _G', '@t', env)(), nil, 'no _G handle')
end)

F.test('protected names cannot be overwritten', function()
    local env = sandbox.new_env({ bind = function() end }, { bind = true }, 'scope_a')
    F.raises(function()
        env.bind = nil
    end, "define('scope_a')", 'guard reports the scope id')
end)

F.test('environments built from one api are independent', function()
    local api = {}
    local a = sandbox.new_env(api)
    local b = sandbox.new_env(api)
    a.only_in_a = 1
    F.eq(rawget(b, 'only_in_a'), nil, 'b does not see a')
end)

F.test('a syntax error is reported by the caller', function()
    local chunk, err = sandbox.load_chunk('this is not lua', '@t', {})
    F.eq(chunk, nil, 'no chunk')
    F.ok(err ~= nil, 'an error is returned')
end)

--== module registry =======================================================

F.section('define: module registry')

F.test('import flattens a data module into the env', function()
    local modules = ModuleRegistry()
    modules:add('mp', { get_prop = function(name) return 'v:' .. name end })
    local env = sandbox.new_env({})
    modules:import_into('mp', env, 's')
    F.eq(env.get_prop('pause'), 'v:pause', 'name available without a prefix')
end)

F.test('importing an unknown module raises ImportError', function()
    F.raises(function()
        ModuleRegistry():import_into('nope', sandbox.new_env({}), 's')
    end, 'ImportError', 'unknown module')
end)

F.test('the loader runs after the copy and receives the scope id', function()
    local modules = ModuleRegistry()
    modules:add('mp', { greet = function() return 'hi' end })
    modules:add_loader('mp', function(env, scope_id)
        local original = env.greet
        env.greet = function()
            return original() .. ' from ' .. scope_id
        end
    end)
    local env = sandbox.new_env({})
    modules:import_into('mp', env, 'scope_a')
    F.eq(env.greet(), 'hi from scope_a', 'loader wrapped the imported name')
end)

F.test('a loader alone is a valid module', function()
    local modules = ModuleRegistry()
    modules:add_loader('bare', function(env, scope_id)
        env.installed = scope_id
    end)
    local env = sandbox.new_env({})
    modules:import_into('bare', env, 's')
    F.eq(env.installed, 's', 'loader installed a name')
end)

F.test('publish refuses to shadow a protected module', function()
    local modules = ModuleRegistry()
    modules:add('mp', {})
    modules:protect('mp')
    F.eq(modules:is_protected('mp'), true, 'protected')
    F.raises(function()
        modules:publish('mp', {})
    end, 'RuntimeError', 'protected module')
end)

F.test('publish rejects a non-table payload', function()
    F.raises(function()
        ModuleRegistry():add('x', 'nope' --[[@as any]])
    end, 'TypeError', 'module must be a table')
end)

F.test('has / get see data modules and loaders alike', function()
    local modules = ModuleRegistry()
    modules:add('data', { a = 1 })
    modules:add_loader('loader', function() end)
    F.eq(modules:has('data'), true, 'data module')
    F.eq(modules:has('loader'), true, 'loader-only module')
    F.eq(modules:has('nope'), false, 'unknown')
    F.eq(modules:get('data').a, 1, 'payload')
end)

--== define protocol =======================================================

F.section('define: protocol')

F.test('builtins are readable from every scope', function()
    local session = DefineSession({ builtins = { Text = Text, answer = 42 } })
    session:define_start()
    session:define('s', 'label = Text(answer)')
    local env = session:env_for('s')
    F.eq(env.answer, 42, 'builtin visible')
    F.ok(env.label ~= nil, 'builtin constructible')
end)

F.test('a scope keeps its first payload only', function()
    local session = DefineSession()
    session:define_start()
    session:define('s', 'count = 1')
    session:define('s', 'count = count + 1')
    F.eq(session:env_for('s').count, 1, 'duplicate payload is ignored')
end)

F.test('the phase is refcounted: every starter must end', function()
    local session = DefineSession()
    session:define_start()
    session:define_start()
    F.eq(session.phase, 'defining', 'two starters, still open')
    session:define_end()
    F.eq(session.phase, 'defining', 'one starter left')
    session:define_end()
    F.eq(session.phase, 'sealed', 'every starter ended')
end)

F.test('define_start after the seal raises', function()
    local session = DefineSession()
    session:define_start()
    session:define_end()
    F.raises(function()
        session:define_start()
    end, 'RuntimeError', 'sealed session')
end)

F.test('define_end without a starter raises', function()
    local session = DefineSession()
    F.raises(function()
        session:define_end()
    end, 'RuntimeError', 'idle session')
end)

F.test('define_end after the seal raises', function()
    local session = DefineSession()
    session:define_start()
    session:define_end()
    F.raises(function()
        session:define_end()
    end, 'RuntimeError', 'already sealed')
end)

F.test('define is rejected outside the define phase', function()
    local session = DefineSession()
    F.raises(function()
        session:define('s', 'x = 1')
    end, 'RuntimeError', 'idle session')
    session:define_start()
    session:define_end()
    F.raises(function()
        session:define('s', 'x = 1')
    end, 'RuntimeError', 'sealed session')
end)

F.test('a bad payload is reported with its scope id', function()
    local session = DefineSession()
    session:define_start()
    F.raises(function()
        session:define('scope_a', 'this is not lua')
    end, "define('scope_a')", 'syntax errors carry the scope id')
end)

F.test('a failed first payload still consumes the scope', function()
    local accepted = 0
    local session = DefineSession()
    session.on_error = function()
        accepted = accepted + 1
    end
    session:define_start()
    session:define('broken', 'this is not lua')
    session:define('broken', 'accepted = true')
    session:define_end()
    F.eq(accepted, 2, 'syntax failure and duplicate are both reported')
    F.eq(session:env_for('broken').accepted, nil, 'second payload was ignored')
end)

F.test('on_error intercepts a broken payload', function()
    local session = DefineSession()
    local caught
    session.on_error = function(scope_id, err)
        caught = { scope_id = scope_id, err = err }
    end
    session:define_start()
    session:define('s', 'this is not lua')
    F.eq(caught.scope_id, 's', 'scope id forwarded')
    F.ok(caught.err ~= nil, 'error forwarded')
end)

--== mod / import / bind ===================================================

F.section('define: mod / import / bind')

F.test('mod publishes the current scope for another scope to import', function()
    local session = DefineSession()
    session:define_start()
    session:define('producer', 'answer = 42\nmod("shared")')
    session:define('consumer', "import('shared')\ncopy = answer")
    F.eq(session:env_for('consumer').copy, 42, 'cross-scope sharing')
end)

F.test('mod can publish an explicit table', function()
    local session = DefineSession()
    session:define_start()
    session:define('s', "mod('inline', { value = 7 })")
    session:define('t', "import('inline')\ncopy = value")
    F.eq(session:env_for('t').copy, 7, 'explicit payload published')
end)

F.test('a host module imported by a chunk works end to end', function()
    local modules = ModuleRegistry()
    modules:add('mp', { get_prop = function(name) return 'v:' .. name end })
    modules:add_loader('mp', function(env)
        env.on_message = function(cb) env.message_handler = cb end
    end)
    local session = DefineSession({ modules = modules })
    session:define_start()
    session:define('s', [[
        import('mp')
        pause = get_prop('pause')
        on_message(function() end)
    ]])
    local env = session:env_for('s')
    F.eq(env.pause, 'v:pause', 'data module flattened')
    F.ok(env.message_handler ~= nil, 'loader installed a scope-aware function')
end)

F.test('the framework provides no host services of its own', function()
    local session = DefineSession()
    session:define_start()
    F.raises(function()
        session:define('s', 'on_message(function() end)')
    end, 'nil value', 'on_message only exists if a host module installs it')
end)

F.test('import outside a payload raises', function()
    local session = DefineSession()
    F.raises(function()
        session.api['import']('mp')
    end, 'RuntimeError', 'no current env')
end)

F.test('bind inside a chunk lands in the session registry', function()
    local session = DefineSession({ builtins = { Text = Text } })
    session:define_start()
    session:define('scope_a', "bind('slot', Text('hi'))")
    session:define_end()

    local owner = mount(Column({ children = { Slot('slot') } }), session.binds)
    F.eq(owner.root:children()[1].paragraph.text, 'hi', 'bound into the slot')
end)

F.test('define bind entries belong to their declaring scopes', function()
    local session = DefineSession({ builtins = { Text = Text } })
    session:define_start()
    session:define('scope_a', "bind('a', Text('a'))")
    session:define('scope_b', "bind('b', Text('b'))")

    local entries_a = session.binds:entries('scope_a')
    local entries_b = session.binds:entries('scope_b')
    F.eq(#entries_a, 1, 'scope a entry')
    F.eq(#entries_b, 1, 'scope b entry')
    F.eq(entries_a[1].scope_id, 'scope_a', 'scope a recorded')
    F.eq(entries_b[1].scope_id, 'scope_b', 'scope b recorded')
end)

F.test('removing one define scope leaves another scope bindable', function()
    local session = DefineSession({ builtins = { Text = Text } })
    session:define_start()
    session:define('scope_a', "bind('a', Text('a'))")
    session:define('scope_b', "bind('b', Text('b'))")
    session.binds:remove_scope('scope_a')

    local owner = mount(Column({
        children = { Slot('a'), Slot('b') },
    }), session.binds)
    F.eq(#owner.root:children(), 1, 'only scope b rendered')
    F.eq(owner.root:children()[1].paragraph.text, 'b', 'scope b remains')
end)

F.test('a scope accepts only its first define payload', function()
    local warnings = 0
    local session = DefineSession({ builtins = { Text = Text } })
    session.on_error = function()
        warnings = warnings + 1
    end
    session:define_start()
    session:define('scope_once', "first = 'accepted'")
    session:define('scope_once', "first = 'rejected'")
    session:define_end()
    F.eq(warnings, 1, 'duplicate scope warning')
    F.eq(session:env_for('scope_once').first, 'accepted', 'first payload retained')
end)
