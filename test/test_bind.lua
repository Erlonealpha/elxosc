-- Inherited widgets and `bind` (named targets, define-time only).

-- See the note in test_widget.lua: the `std.class` / optional-ownership
-- diagnostics are disabled across the suite.
---@diagnostic disable: undefined-field, inject-field, need-check-nil, generic-constraint-mismatch, preferred-local-alias, unused, call-non-callable

local F = require('framework')
local std = require('elxlibs.std')

local constraints_mod = require('layout.constraints')
local render_owner = require('render.render_owner')
local widget_mod = require('widget.widget')
local binding_mod = require('widget.binding')
local layout_widgets = require('widget.widgets.layout')
local basic_widgets = require('widget.widgets.basic')
local bind_mod = require('widget.bind')

local Constraints = constraints_mod.Constraints
local RenderOwner = render_owner.RenderOwner
local WidgetBinding = binding_mod.WidgetBinding
local StatelessWidget = widget_mod.StatelessWidget
local InheritedWidget = widget_mod.InheritedWidget
local Column = layout_widgets.Column
local SizedBox = layout_widgets.SizedBox
local Text = basic_widgets.Text
local BindRegistry = bind_mod.BindRegistry
local Slot = bind_mod.Slot

---@param widget Widget
---@param binds BindRegistry?
local function mount(widget, binds)
    local owner = RenderOwner()
    local binding = WidgetBinding(widget, owner, binds)
    owner:set_viewport(Constraints.loose(1000, 1000))
    owner:layout()
    return owner, binding
end

--== inherited widgets =====================================================

F.section('bind: inherited widgets')

local Theme = std.class.new('test.Theme', { InheritedWidget })
function Theme:__init(value, options)
    options = options or {}
    self.key = options.key
    self.value = value
    self.child = options.child
end

local Show = std.class.new('test.Show', { StatelessWidget })
function Show:build(context)
    local theme = context:depend_on_inherited(Theme)
    return Text(theme and theme.value or 'none')
end

F.test('descendants read the value without prop drilling', function()
    local owner = mount(Theme('dark', { child = Column({ children = { Show() } }) }))
    F.eq(owner.root:children()[1].paragraph.text, 'dark', 'read from the ancestor')
end)

F.test('the lookup returns nothing when no provider is above', function()
    local owner = mount(Column({ children = { Show() } }))
    F.eq(owner.root:children()[1].paragraph.text, 'none', 'no provider')
end)

F.test('replacing the provider updates dependents', function()
    local owner, binding = mount(Theme('dark', { child = Column({ children = { Show() } }) }))
    binding:set_root_widget(Theme('light', { child = Column({ children = { Show() } }) }))
    owner:layout()
    F.eq(owner.root:children()[1].paragraph.text, 'light', 'rebuilt with the new value')
end)

--== bind ==================================================================

F.section('bind: named targets')

F.test('writes the bound widget into the target child slot', function()
    local binds = BindRegistry()
    binds:add('title', Text('bound'))
    local owner = mount(Column({ children = { SizedBox({ id = 'title' }) } }), binds)
    local target = owner.root:children()[1]
    F.eq(target:children()[1].paragraph.text, 'bound', 'bound into the target')
end)

F.test('replace is the default and overwrites an existing child', function()
    local binds = BindRegistry()
    binds:add('title', Text('new'))
    local owner = mount(SizedBox({ id = 'title', child = Text('old') }), binds)
    F.eq(owner.root:children()[1].paragraph.text, 'new', 'replaced')
end)

F.test('replace_if_empty leaves an existing child alone', function()
    local binds = BindRegistry()
    binds:add('title', Text('new'), { op = 'replace_if_empty' })
    local owner = mount(SizedBox({ id = 'title', child = Text('old') }), binds)
    F.eq(owner.root:children()[1].paragraph.text, 'old', 'kept')
end)

F.test('appends into a multi-child target', function()
    local binds = BindRegistry()
    binds:add('bar', Text('b'))
    local owner = mount(Column({ id = 'bar', children = { Text('a') } }), binds)
    F.eq(#owner.root:children(), 2, 'appended')
    F.eq(owner.root:children()[2].paragraph.text, 'b', 'at the end')
end)

F.test('inserts at a position in a multi-child target', function()
    local binds = BindRegistry()
    binds:add('bar', Text('b'), { op = 'insert', position = 1 })
    local owner = mount(Column({ id = 'bar', children = { Text('a') } }), binds)
    F.eq(owner.root:children()[1].paragraph.text, 'b', 'inserted first')
    F.eq(owner.root:children()[2].paragraph.text, 'a', 'original shifted')
end)

F.test('binds reach widgets added by other binds', function()
    local binds = BindRegistry()
    binds:add('outer', Column({ id = 'inner', children = {} }))
    binds:add('inner', Text('deep'))
    local owner = mount(SizedBox({ id = 'outer' }), binds)
    local inner = owner.root:children()[1]
    F.eq(inner:children()[1].paragraph.text, 'deep', 'nested bind applied')
end)

F.test('unknown ids are ignored', function()
    local binds = BindRegistry()
    binds:add('nope', Text('x'))
    local owner = mount(Column({ children = { Text('a') } }), binds)
    F.eq(#owner.root:children(), 1, 'nothing added')
end)

F.test('binding to a widget that cannot take children raises', function()
    local binds = BindRegistry()
    binds:add('t', Text('x'))
    F.raises(function()
        binds:apply(Text('y', { id = 't' }))
    end, 'RuntimeError', 'single leaf target')
end)

F.test('an op that does not match the target kind raises', function()
    local binds = BindRegistry()
    binds:add('t', Text('x'), { op = 'append' })
    F.raises(function()
        binds:apply(SizedBox({ id = 't' }))
    end, 'ValueError', 'append on a single-child target')
end)

F.test('Slot is an empty target a script can fill', function()
    local binds = BindRegistry()
    binds:add('slot', Text('filled'))
    local owner = mount(Column({ children = { Slot('slot'), Slot('empty') } }), binds)
    F.eq(#owner.root:children(), 1, 'unbound slot contributes nothing')
    F.eq(owner.root:children()[1].paragraph.text, 'filled', 'bound slot rendered')
end)

F.test('bindings added after apply do not mutate the mounted tree', function()
    local binds = BindRegistry()
    binds:add('title', Text('first'))
    local owner, binding = mount(SizedBox({ id = 'title' }), binds)
    F.eq(owner.root:children()[1].paragraph.text, 'first', 'initial')

    binds:add('title', Text('late'))
    binding:flush_build()
    owner:layout()
    F.eq(owner.root:children()[1].paragraph.text, 'first', 'tree stays fixed at runtime')
end)

F.test('scope removal keeps other pending bindings', function()
    local binds = BindRegistry()
    binds:add('a', Text('scope a'), nil, 'scope_a')
    binds:add('b', Text('scope b'), nil, 'scope_b')

    binds:remove_scope('scope_a')
    F.eq(#binds:entries(), 1, 'one binding remains')
    F.eq(binds:entries()[1].scope_id, 'scope_b', 'other scope remains')
end)

F.test('scope removal after apply does not undo the applied tree', function()
    local binds = BindRegistry()
    binds:add('slot', Text('applied'), nil, 'scope_a')
    local root = SizedBox({ id = 'slot' })
    binds:apply(root)

    binds:clear_scope('scope_a')
    F.eq(#binds:entries(), 0, 'pending entry was removed')
    F.eq(root.child.text, 'applied', 'applied tree remains')
end)
