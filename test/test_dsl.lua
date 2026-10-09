-- The define DSL factories: `new_widget` / `new_state` / `builtins`.

-- See the note in test_widget.lua: the `std.class` / optional-ownership
-- diagnostics are disabled across the suite.
---@diagnostic disable: undefined-field, inject-field, need-check-nil, generic-constraint-mismatch, preferred-local-alias, unused

local F = require('framework')
local std = require('elxlibs.std')

local dsl = require('libs.dsl')

local text_layout = require('text.text_layout')
local constraints_mod = require('layout.constraints')
local render_owner = require('render.render_owner')
local binding_mod = require('widget.binding')
local widget_mod = require('widget.widget')
local state_mod = require('widget.state')
local layout_widgets = require('widget.widgets.layout')
local basic_widgets = require('widget.widgets.basic')

local Constraints = constraints_mod.Constraints
local RenderOwner = render_owner.RenderOwner
local WidgetBinding = binding_mod.WidgetBinding
local StatefulWidget = widget_mod.StatefulWidget
local State = state_mod.State
local Column = layout_widgets.Column
local Text = basic_widgets.Text

-- Deterministic measurer: half the font size per character (see test_widget.lua).
local FixedLayout = std.class.new('test.dsl.FixedLayout', { text_layout.TextLayout })
function FixedLayout:line_width(line, style)
    return #line * style.font_size * 0.5
end
text_layout.set_default(FixedLayout() --[[@as TextLayout]])

---@param widget Widget
local function mount(widget)
    local owner = RenderOwner()
    local binding = WidgetBinding(widget, owner)
    owner:set_viewport(Constraints.loose(1000, 1000))
    owner:layout()
    return owner, binding
end

--== factories =============================================================

F.section('dsl: factories')

F.test('new_widget builds a StatefulWidget subclass', function()
    local W = dsl.new_widget('test.W')
    F.eq(std.isinstance(W(), StatefulWidget), true, 'instance of StatefulWidget')
end)

F.test('new_state builds a State subclass', function()
    local S = dsl.new_state('test.S')
    F.eq(std.isinstance(S(), State), true, 'instance of State')
end)

F.test('the parent class can be overridden', function()
    local Base = dsl.new_state('test.Base')
    local Child = dsl.new_state('test.Child', Base)
    F.eq(std.isinstance(Child(), Base), true, 'subclass of the given parent')
end)

--== builtins ==============================================================

F.section('dsl: builtins')

F.test('builtins exposes the widget library', function()
    local b = dsl.builtins()
    F.ok(b.Text ~= nil, 'Text')
    F.ok(b.Container ~= nil, 'Container')
    F.ok(b.Slot ~= nil, 'Slot')
    F.ok(b.Column ~= nil, 'Column')
    F.ok(b.Button ~= nil, 'Button')
end)

F.test('builtins exposes the value types', function()
    local b = dsl.builtins()
    F.ok(b.EdgeInsets ~= nil, 'EdgeInsets')
    F.ok(b.Color ~= nil, 'Color')
    F.ok(b.TextStyle ~= nil, 'TextStyle')
end)

F.test('builtins exposes the two factories', function()
    local b = dsl.builtins()
    F.eq(b.new_widget, dsl.new_widget, 'new_widget')
    F.eq(b.new_state, dsl.new_state, 'new_state')
end)

--== end to end ============================================================

F.section('dsl: a declared widget runs')

F.test('a new_widget + new_state pair builds and mounts', function()
    local Counter = dsl.new_state('test.Counter')
    function Counter:__init()
        std.super(Counter, self, State).__init(self)
        self.value = 3
    end
    function Counter:build()
        return Text('n=' .. self.value)
    end

    local CounterWidget = dsl.new_widget('test.CounterWidget')
    function CounterWidget:create_state()
        return Counter()
    end

    local owner = mount(Column({ children = { CounterWidget() } }))
    F.eq(owner.root:children()[1].paragraph.text, 'n=3', 'state drove the build')
end)
