-- The define DSL factories: `new_widget` / `new_state` / `builtins`.

-- See the note in test_widget.lua: the `std.class` / optional-ownership
-- diagnostics are disabled across the suite.
---@diagnostic disable: undefined-field, inject-field, need-check-nil, generic-constraint-mismatch, preferred-local-alias, unused

local F = require('framework')
local std = require('elxlibs.std')

local dsl = require('libs.dsl')

local text_layout = require('text.text_layout')
local text_style_mod = require 'text.text_style'
local transform_mod = require 'foundation.transform'
local anchor_mod = require 'foundation.anchor'
local text_paint_mod = require 'painting.text_paint'
local constraints_mod = require('layout.constraints')
local render_owner = require('render.render_owner')
local binding_mod = require('widget.binding')
local widget_mod = require('widget.widget')
local state_mod = require('widget.state')
local layout_widgets = require('widget.widgets.layout')
local basic_widgets = require('widget.widgets.basic')
local text_widgets = require('widget.widgets.text')
local custom_paint_widgets = require('widget.widgets.custom_paint')
local gesture_widgets = require('widget.widgets.gesture_detector')
local button_widgets = require('widget.widgets.button')
local padding_widgets = require('widget.widgets.padding')
local align_widgets = require('widget.widgets.align')
local sized_box_widgets = require('widget.widgets.sized_box')
local decorated_box_widgets = require('widget.widgets.decorated_box')
local flex_widgets = require('widget.widgets.flex')
local stack_widgets = require('widget.widgets.stack')
local constraints_widgets = require('widget.widgets.constraints')
local overflow_widgets = require('widget.widgets.overflow')
local container_widgets = require('widget.widgets.container')

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
    local binding = WidgetBinding.ensure_initialized():attach(widget, owner)
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
    F.ok(b.Icon ~= nil, 'Icon')
    F.ok(b.Container ~= nil, 'Container')
    F.ok(b.SlotSpec ~= nil, 'SlotSpec')
    F.ok(b.SlotWrap ~= nil, 'SlotWrap')
    F.ok(b.Column ~= nil, 'Column')
    F.ok(b.Button ~= nil, 'Button')
    F.ok(b.TransformBox ~= nil, 'TransformBox')
    F.ok(b.LayoutScaleBox ~= nil, 'LayoutScaleBox')
end)

F.test('Slot aggregate exports preserve direct-module identity', function()
    local b = dsl.builtins()
    local slot = require('widget.slot')
    local widget_api = require('widget')
    F.eq(b.SlotSpec, slot.SlotSpec, 'DSL SlotSpec')
    F.eq(widget_api.SlotSpec, slot.SlotSpec, 'widget SlotSpec')
    F.eq(widget_api.CompositionAssembler, slot.CompositionAssembler,
        'widget CompositionAssembler')
end)

F.test('basic widget module remains a compatibility aggregate', function()
    F.eq(basic_widgets.Text, text_widgets.Text, 'Text')
    F.eq(basic_widgets.CustomPaint, custom_paint_widgets.CustomPaint, 'CustomPaint')
    F.eq(basic_widgets.GestureDetector, gesture_widgets.GestureDetector, 'GestureDetector')
    F.eq(basic_widgets.Button, button_widgets.Button, 'Button')
end)

F.test('layout modules and aggregate preserve class identity', function()
    local widget_api = require('widget')
    local expected = {
        Padding = padding_widgets.Padding, Align = align_widgets.Align, Center = align_widgets.Center,
        SizedBox = sized_box_widgets.SizedBox, DecoratedBox = decorated_box_widgets.DecoratedBox,
        Flexible = flex_widgets.Flexible, Expanded = flex_widgets.Expanded, Spacer = flex_widgets.Spacer,
        Flex = flex_widgets.Flex, Row = flex_widgets.Row, Column = flex_widgets.Column,
        Stack = stack_widgets.Stack, ConstrainedBox = constraints_widgets.ConstrainedBox,
        LimitedBox = constraints_widgets.LimitedBox, UnconstrainedBox = overflow_widgets.UnconstrainedBox,
        OverflowBox = overflow_widgets.OverflowBox, FittedBox = overflow_widgets.FittedBox,
        Container = container_widgets.Container,
        OffsetBox = layout_widgets.OffsetBox,
        TransformBox = layout_widgets.TransformBox,
        LayoutScaleBox = layout_widgets.LayoutScaleBox,
    }
    for name, value in pairs(expected) do
        F.eq(layout_widgets[name], value, name .. ' aggregate')
        F.eq(widget_api[name], value, name .. ' widget API')
    end
end)

F.test('builtins exposes the value types', function()
    local b = dsl.builtins()
    F.ok(b.EdgeInsets ~= nil, 'EdgeInsets')
    F.ok(b.Color ~= nil, 'Color')
    F.ok(b.TextStyle ~= nil, 'TextStyle')
    F.ok(rawequal(b.Matrix2D, transform_mod.Matrix2D), 'Matrix2D')
    F.ok(rawequal(b.TextStyle, text_style_mod.TextStyle), 'DSL and direct-module style class identity')
    F.ok(rawequal(b.Anchor, anchor_mod.Anchor), 'Anchor constants')
    F.ok(rawequal(b.TextPaint, text_paint_mod.TextPaint), 'DSL and direct-module paint class identity')
    local style = b.TextStyle({ font_size = 12.5, wrap = false })
    F.eq(style.font_size, 12.5, 'DSL constructor uses options')
    F.eq(style.wrap, false, 'DSL constructor keeps false')
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
