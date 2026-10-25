-- Initialization-only Slot contributions and immutable assembly.

---@diagnostic disable: undefined-field, inject-field, need-check-nil, generic-constraint-mismatch, preferred-local-alias, unused

local F = require('framework')
local std = require('elxlibs.std')

local text_layout = require('text.text_layout')
local constraints_mod = require('layout.constraints')
local render_owner = require('render.render_owner')
local widget_mod = require('widget.widget')
local binding_mod = require('widget.binding')
local layout_widgets = require('widget.widgets.layout')
local basic_widgets = require('widget.widgets.basic')
local slot_mod = require('widget.slot')

local Constraints = constraints_mod.Constraints
local RenderOwner = render_owner.RenderOwner
local WidgetBinding = binding_mod.WidgetBinding
local StatelessWidget = widget_mod.StatelessWidget
local InheritedWidget = widget_mod.InheritedWidget
local Column = layout_widgets.Column
local SizedBox = layout_widgets.SizedBox
local Text = basic_widgets.Text
local SlotSpec = slot_mod.SlotSpec
local SlotWrap = slot_mod.SlotWrap
local ContributionRegistry = slot_mod.ContributionRegistry
local CompositionAssembler = slot_mod.CompositionAssembler

local FixedLayout = std.class.new('test.bind.FixedLayout', { text_layout.TextLayout })
function FixedLayout:line_width(line, style)
    return #line * style.font_size * 0.5
end
text_layout.set_default(FixedLayout())

local function mount(widget)
    local owner = RenderOwner()
    local binding = WidgetBinding.ensure_initialized():attach(widget, owner)
    owner:set_viewport(Constraints.loose(1000, 1000))
    owner:layout()
    return owner, binding
end

local function assemble(root, registry)
    local assembler = CompositionAssembler(registry and registry:seal() or {})
    return assembler:assemble(root)
end

--== inherited widgets ======================================================

F.section('bind: inherited widgets')

local Theme = std.class.new('test.bind.Theme', { InheritedWidget })
function Theme:__init(value, options)
    options = options or {}
    self.key = options.key
    self.value = value
    self.child = options.child
end

local Show = std.class.new('test.bind.Show', { StatelessWidget })
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

--== Slot protocol ==========================================================

F.section('bind: Slot contributions')

F.test('set replaces the Slot value without mutating the input description', function()
    local default = Text('default')
    local spec = SlotSpec({ id = 'title', allow = { 'set' }, default_op = 'set' })
    local root = SlotWrap(spec, default)
    local registry = ContributionRegistry()
    local options = { op = 'set', marker = 'caller' }
    registry:add('title', Text('bound'), options, 'scope_a')
    local assembled = assemble(root, registry)
    local owner = mount(assembled)

    F.eq(owner.root.paragraph.text, 'bound', 'set value is mounted')
    F.eq(root.default_value, default, 'caller-owned default remains unchanged')
    F.eq(options.op, 'set', 'caller-owned options remain unchanged')
end)

F.test('set keeps the first valid contribution and diagnoses later values', function()
    local spec = SlotSpec({ id = 'title', allow = { 'set' }, default_op = 'set' })
    local registry = ContributionRegistry()
    registry:add('title', Text('first'), { op = 'set' }, 'a')
    registry:add('title', Text('second'), { op = 'set' }, 'b')
    local assembler = CompositionAssembler(registry:seal())
    local assembled = assembler:assemble(SlotWrap(spec, Text('default')))
    local owner = mount(assembled)

    F.eq(owner.root.paragraph.text, 'first', 'first set wins')
    F.eq(#assembler.diagnostics, 1, 'later set is diagnosed')
end)

F.test('replace is repeatable and the last valid replacement wins', function()
    local spec = SlotSpec({ id = 'app', allow = { 'replace' }, default_op = 'replace' })
    local registry = ContributionRegistry()
    registry:add('app', Text('first'), { op = 'replace' }, 'a')
    registry:add('app', Text('last'), { op = 'replace' }, 'b')
    local assembled = assemble(SlotWrap(spec, Text('default')), registry)
    local owner = mount(assembled)
    F.eq(owner.root.paragraph.text, 'last', 'last replacement wins')
end)

F.test('append uses SlotSpec ordering and generated identities', function()
    local spec = SlotSpec({
        id = 'actions',
        allow = { 'append' },
        default_op = 'append',
        default_value = { Text('default') },
        builder = function(value)
            local children = value
            ---@cast children Widget[]
            return Column({ children = children })
        end,
    })
    local registry = ContributionRegistry()
    registry:add('actions', Text('last'), { op = 'append', name = 'last', priority = 1 }, 'a')
    registry:add('actions', Text('first'), { op = 'append', name = 'first', pos = 'first', priority = 2 }, 'b')
    local assembled = assemble(SlotWrap(spec), registry)
    local owner = mount(assembled)
    local children = owner.root:children()
    F.eq(children[1].paragraph.text, 'first', 'first position is honored')
    F.eq(children[2].paragraph.text, 'default', 'default content is retained')
    F.eq(children[3].paragraph.text, 'last', 'append content is present')
end)

F.test('deep contributions resolve after a shallow replacement', function()
    local title_spec = SlotSpec({ id = 'title', allow = { 'set' }, default_op = 'set' })
    local app_spec = SlotSpec({ id = 'app', allow = { 'replace' }, default_op = 'replace' })
    local custom_app = Column({ children = { SlotWrap(title_spec, Text('custom default')) } })
    local registry = ContributionRegistry()
    registry:add('title', Text('deep'), { op = 'set' }, 'deep')
    registry:add('app', custom_app, { op = 'replace' }, 'shallow')
    local assembled = assemble(SlotWrap(app_spec, Text('default app')), registry)
    local owner = mount(assembled)
    F.eq(owner.root:children()[1].paragraph.text, 'deep', 'deep bind reaches replacement tree')
end)

F.test('unknown and invalid contributions are ignored with diagnostics', function()
    local spec = SlotSpec({ id = 'known', allow = { 'set' }, default_op = 'set' })
    local registry = ContributionRegistry()
    registry:add('known', Text('bad'), { op = 'append' }, 'bad-op')
    registry:add('unknown', Text('lost'), { op = 'set' }, 'unknown')
    local assembler = CompositionAssembler(registry:seal())
    local assembled = assembler:assemble(SlotWrap(spec, Text('default')))
    local owner = mount(assembled)
    F.eq(owner.root.paragraph.text, 'default', 'invalid values do not replace defaults')
    F.eq(#assembler.diagnostics, 2, 'both failures are diagnosed')
end)

F.test('sealed contributions reject new bind calls', function()
    local registry = ContributionRegistry()
    registry:add('title', Text('one'), nil, 'scope')
    registry:seal()
    F.raises(function()
        registry:add('title', Text('two'), nil, 'scope')
    end, 'RuntimeError', 'sealed registry')
end)
