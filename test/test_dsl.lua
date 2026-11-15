-- Define class factories and the host's explicit builtins surface.
---@namespace test.dsl
---@using elxosc

-- See the note in test_widget.lua: the `std.class` / optional-ownership
-- diagnostics are disabled across the suite.
---@diagnostic disable: undefined-field, inject-field, need-check-nil, preferred-local-alias, unused

local F = require('framework')
local std = require('elxlibs.std')

local dsl = require('define.src.dsl')
local mp_stub = require 'mp_stub'
mp_stub.install()
local host_define = require 'host.mpv_define'

local text_layout = require('src.text.text_layout')
local text_style_mod = require 'src.text.text_style'
local transform_mod = require 'src.foundation.transform'
local anchor_mod = require 'src.foundation.anchor'
local text_paint_mod = require 'src.painting.text_paint'
local constraints_mod = require('src.layout.constraints')
local render_owner = require('src.render.render_owner')
local binding_mod = require('src.widgets.binding')
local widget_mod = require('src.widgets.framework')
local state_mod = require('src.widgets.state')
local layout_widgets = require('widgets')
local basic_widgets = require('material')
local text_widgets = require('src.widgets.text')
local custom_paint_widgets = require('src.widgets.custom_paint')
local gesture_widgets = require('src.widgets.gesture_detector')
local button_widgets = require('src.material.button')
local padding_widgets = require('src.widgets.padding')
local align_widgets = require('src.widgets.align')
local sized_box_widgets = require('src.widgets.sized_box')
local decorated_box_widgets = require('src.widgets.decorated_box')
local flex_widgets = require('src.widgets.flex')
local stack_widgets = require('src.widgets.stack')
local constraints_widgets = require('src.widgets.constraints')
local overflow_widgets = require('src.widgets.overflow')
local container_widgets = require('src.widgets.container')
local slot_mod = require 'define.src.slot'

local Constraints = constraints_mod.Constraints
local RenderOwner = render_owner.RenderOwner
local WidgetBinding = binding_mod.WidgetBinding
local StatefulWidget = widget_mod.StatefulWidget
local State = state_mod.State
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
    ---@class W : StatefulWidget
    ---@overload fun(): self
    local W = dsl.new_widget('test.W' --[[@as 'test.dsl.W']])
    F.eq(std.isinstance(W(), StatefulWidget), true, 'instance of StatefulWidget')
end)

F.test('new_state builds a State subclass', function()
    ---@class S : State
    ---@overload fun(): self
    local S = dsl.new_state('test.S' --[[@as 'test.dsl.S']])
    F.eq(std.isinstance(S(), State), true, 'instance of State')
end)

F.test('the parent class can be overridden', function()
    ---@class Base : State
    ---@overload fun(): self
    local Base = dsl.new_state('test.Base' --[[@as 'test.dsl.Base']])
    ---@class Child : Base
    ---@overload fun(): self
    local Child = dsl.new_state('test.Child' --[[@as 'test.dsl.Child']], Base)
    F.eq(std.isinstance(Child(), Base), true, 'subclass of the given parent')
end)

--== builtins ==============================================================

F.section('host define: builtins')

F.test('builtins contains only the two class factories', function()
    local b = host_define.builtins()
    local count = 0
    for name, value in pairs(b) do
        count = count + 1
        F.ok(name == 'new_widget' or name == 'new_state', 'explicit factory name: ' .. name)
        F.eq(value, dsl[name], 'canonical class factory: ' .. name)
    end
    F.eq(count, 2, 'only factory exports')
end)

F.test('Slot aggregate exports preserve direct-module identity', function()
    local define_api = require('define')
    F.eq(define_api.SlotSpec, slot_mod.SlotSpec, 'Define SlotSpec')
    F.eq(define_api.CompositionAssembler, slot_mod.CompositionAssembler,
        'Define CompositionAssembler')
end)

F.test('basic widget module remains a compatibility aggregate', function()
    F.eq(basic_widgets.Text, text_widgets.Text, 'Text')
    F.eq(basic_widgets.CustomPaint, custom_paint_widgets.CustomPaint, 'CustomPaint')
    F.eq(basic_widgets.GestureDetector, gesture_widgets.GestureDetector, 'GestureDetector')
    F.eq(basic_widgets.Button, button_widgets.Button, 'Button')
end)

F.test('layout modules and aggregate preserve class identity', function()
    local widget_api = require('src.widgets')
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

F.test('material collector exposes value types with direct identity', function()
    local b = basic_widgets
    F.ok(b.EdgeInsets ~= nil, 'EdgeInsets')
    F.ok(b.Color ~= nil, 'Color')
    F.ok(b.TextStyle ~= nil, 'TextStyle')
    F.ok(rawequal(b.Matrix2D, transform_mod.Matrix2D), 'Matrix2D')
    F.ok(rawequal(b.TextStyle, text_style_mod.TextStyle), 'material and direct-module style class identity')
    F.ok(rawequal(b.Anchor, anchor_mod.Anchor), 'Anchor constants')
    F.ok(rawequal(b.TextPaint, text_paint_mod.TextPaint), 'material and direct-module paint class identity')
    local style = b.TextStyle({ font_size = 12.5, wrap = false })
    F.eq(style.font_size, 12.5, 'imported constructor uses options')
    F.eq(style.wrap, false, 'imported constructor keeps false')
end)

F.test('builtins exposes the two factories', function()
    local b = host_define.builtins()
    F.eq(b.new_widget, dsl.new_widget, 'new_widget')
    F.eq(b.new_state, dsl.new_state, 'new_state')
end)

F.test('builtins exclude registry and runtime assembly helpers', function()
    local b = host_define.builtins()
    F.eq(b.BuildOwner, nil, 'build ownership belongs to the runtime')
    F.eq(b.WidgetTree, nil, 'mounted tree management belongs to the runtime')
    F.eq(b.PlayerStore, nil, 'store mutation is not a default builtin')
    F.eq(b.CompositionAssembler, nil, 'host assembles Define contributions')
    F.eq(b.bind, nil, 'DefineSession owns the scope-aware bind entry')
    F.eq(b.geometry_for, nil, 'player geometry helper is not a default builtin')
end)

--== end to end ============================================================

F.section('dsl: a declared widget runs')

F.test('a new_widget + new_state pair builds and mounts', function()
    ---@class Counter : State
    ---@field value number
    ---@overload fun(): self
    local Counter = dsl.new_state('test.Counter' --[[@as 'test.dsl.Counter']])
    function Counter:__init()
        std.super(Counter, self, State).__init(self)
        self.value = 3
    end
    function Counter:build()
        return Text('n=' .. self.value)
    end

    ---@class CounterWidget : StatefulWidget
    ---@overload fun(): self
    local CounterWidget = dsl.new_widget('test.CounterWidget' --[[@as 'test.dsl.CounterWidget']])
    function CounterWidget:create_state()
        return Counter()
    end

    local owner = mount(Column({ children = { CounterWidget() } }))
    F.eq(owner.root:children()[1].paragraph.text, 'n=3', 'state drove the build')
end)
