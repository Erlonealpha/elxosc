-- Widget layer: build -> element -> render object, element reuse and rebuilds.

-- LuaLS cannot model `std.class` field injection, the optional
-- `RenderOwner.root`, or anonymous test stubs, so the diagnostics that stem
-- from those patterns are disabled for the suite.
---@diagnostic disable: undefined-field, inject-field, need-check-nil, generic-constraint-mismatch, preferred-local-alias, unused, call-non-callable

local F = require('framework')
local std = require('elxlibs.std')

local geometry = require('foundation.geometry')
local color = require('foundation.color')
local anchor_mod = require('foundation.anchor')
local text_paint_mod = require('painting.text_paint')
local text_style = require('text.text_style')
local text_layout = require('text.text_layout')
local constraints_mod = require('layout.constraints')
local render_owner = require('render.render_owner')
local record = require('backends.record')
local widget_mod = require('widget.widget')
local key_mod = require('widget.key')
local state_mod = require('widget.state')
local binding_mod = require('widget.binding')
local layout_widgets = require('widget.widgets.layout')
local basic_widgets = require('widget.widgets.basic')

local Offset, Size, EdgeInsets = geometry.Offset, geometry.Size, geometry.EdgeInsets
local Anchor = anchor_mod.Anchor
local Color = color.Color
local TextPaint = text_paint_mod.TextPaint
local TextStyle = text_style.TextStyle
local Constraints = constraints_mod.Constraints
local RenderOwner = render_owner.RenderOwner
local RecordCanvas = record.RecordCanvas
local Key = key_mod.Key
local WidgetBinding = binding_mod.WidgetBinding
local SizedBox = layout_widgets.SizedBox
local Row = layout_widgets.Row
local Column = layout_widgets.Column
local Stack = layout_widgets.Stack
local Container = layout_widgets.Container
local TransformBox = layout_widgets.TransformBox
local LayoutScaleBox = layout_widgets.LayoutScaleBox
local Expanded = layout_widgets.Expanded
local Text = basic_widgets.Text
local Button = basic_widgets.Button
local ButtonStyle = basic_widgets.ButtonStyle
local ElevatedButton = basic_widgets.ElevatedButton
local OutlinedButton = basic_widgets.OutlinedButton
local TextButton = basic_widgets.TextButton
local IconButton = basic_widgets.IconButton

-- Deterministic measurer: half the font size per character.
local FixedLayout = std.class.new('test.FixedLayout', { text_layout.TextLayout })
function FixedLayout:line_width(line, style)
    return #line * style.font_size * 0.5
end
text_layout.set_default(FixedLayout() --[[@as TextLayout]])

---@param widget Widget
---@param constraints Constraints?
local function mount(widget, constraints)
    local owner = RenderOwner()
    local binding = WidgetBinding.ensure_initialized():attach(widget, owner)
    owner:set_viewport(constraints or Constraints.loose(1000, 1000))
    owner:layout()
    return owner, binding
end

--== build -> render tree ==================================================

F.section('widget: build -> render tree')

F.test('the aggregate module exposes the public api', function()
    local api = require('widget')
    F.ok(api.Widget ~= nil, 'Widget')
    F.ok(api.State ~= nil, 'State')
    F.ok(api.WidgetBinding ~= nil, 'WidgetBinding')
    F.ok(api.Container ~= nil, 'Container')
    F.ok(api.Text ~= nil, 'Text')
    F.ok(api.Icon ~= nil, 'Icon')
    F.ok(api.Row ~= nil, 'Row')
    F.ok(api.Button ~= nil, 'Button')
    F.ok(api.ButtonBase ~= nil and api.ButtonStyle ~= nil, 'button base/style')
    F.ok(api.ElevatedButton ~= nil and api.OutlinedButton ~= nil, 'button variants')
    F.ok(api.TextButton ~= nil and api.IconButton ~= nil, 'button variants')
end)

F.test('Button renders and invokes its click callback', function()
    local clicks = 0
    local owner = mount(Button({ label = 'Play', on_click = function() clicks = clicks + 1 end }))
    owner:dispatch_pointer('down', Offset(5, 5))
    owner:dispatch_pointer('up', Offset(5, 5))
    F.eq(clicks, 1, 'button click')
end)

F.test('button variants share the public API and style states', function()
    local variants = { ElevatedButton, OutlinedButton, TextButton, IconButton }
    for _, Variant in ipairs(variants) do
        local clicks = 0
        local button = Variant({ label = 'x', on_click = function() clicks = clicks + 1 end })
        F.ok(button.style ~= nil and button.enabled, 'style and enabled')
        local owner, binding = mount(button)
        owner:dispatch_pointer('down', Offset(2, 2))
        owner:dispatch_pointer('up', Offset(2, 2))
        F.eq(clicks, 1, 'variant click')
        binding:flush_build()
    end
    local custom = ButtonStyle({ background_color = Color.rgba255(1, 2, 3) })
    F.ok(custom:background_for('normal') == Color.rgba255(1, 2, 3), 'custom style')
end)

F.test('mounts a widget tree and paints it', function()
    local owner = mount(Container({
        width = 100,
        height = 40,
        color = Color.rgba255(0x20, 0x20, 0x20),
        radius = 6,
        padding = EdgeInsets.all(4),
        child = Text('hi'),
    }))
    F.ok(owner.root.size == Size(100, 40), 'container size')
    local canvas = RecordCanvas()
    owner:paint(canvas)
    F.eq(canvas.ops[1].name, 'draw_rrect', 'background first')
    F.eq(canvas.ops[2].name, 'draw_text', 'text on top')
end)

F.test('finite scale widgets expose paint-only and layout-affecting boxes', function()
    local paint_owner = mount(TransformBox(SizedBox({ width = 20, height = 10 }), {
        scale = Size(2, 2),
    }))
    F.eq(paint_owner.root.size, Size(20, 10), 'TransformBox keeps the child layout size')
    F.eq(paint_owner.root.scale, Size(2, 2), 'TransformBox config reaches render object')

    local layout_owner = mount(LayoutScaleBox(SizedBox({ width = 20, height = 10 }), {
        scale = Size(2, 2),
    }))
    F.eq(layout_owner.root.size, Size(40, 20), 'LayoutScaleBox reports the scaled size')
    F.eq(layout_owner.root.scale, Size(2, 2), 'LayoutScaleBox config reaches render object')
end)

F.test('Text measures through the ambient TextLayout', function()
    local owner = mount(Text('abcd', { style = TextStyle({ font_size = 10 }) }))
    F.close(owner.root.size.width, 20, '4 chars * 5px')
end)

F.test('Text keeps natural paragraph metrics separate from its constrained box', function()
    local owner = mount(Text('abcd', { style = TextStyle({ font_size = 10 }) }), Constraints.tight(100, 40))
    F.eq(owner.root.size, Size(100, 40), 'layout box obeys tight parent constraints')
    F.eq(owner.root.paragraph.size, Size(20, 12), 'paragraph retains its natural logical size')
    local canvas = RecordCanvas()
    owner:paint(canvas)
    F.eq(canvas.ops[1].name, 'draw_text', 'paragraph is painted')
    F.eq(canvas.ops[1][1].size, Size(20, 12), 'painting receives the natural paragraph')
    F.eq(canvas.ops[1][2], Offset(0, 20), 'left text uses the box middle-left target')
end)

F.test('Text anchors against its constrained box, not natural paragraph size', function()
    local owner = mount(Text('abcd', {
        style = TextStyle({ font_size = 10 }),
        text_paint = TextPaint({ anchor = Anchor.CENTER }),
    }), Constraints.tight(100, 40))
    local canvas = RecordCanvas()
    owner:paint(canvas)
    F.eq(canvas.ops[1][2], Offset(50, 20), 'center target uses the layout box')
    F.eq(canvas.ops[1][3].anchor, Anchor.CENTER, 'paint anchor is preserved')
end)

F.test('changing only TextPaint marks paint without relayout', function()
    local owner, binding = mount(Text('abcd', { style = TextStyle({ font_size = 10 }) }))
    owner:paint(RecordCanvas())
    binding:set_root_widget(Text('abcd', {
        style = TextStyle({ font_size = 10 }),
        text_paint = TextPaint({ anchor = Anchor.CENTER }),
    }))
    F.ok(not owner:needs_layout(), 'paint-only change avoids layout dirty')
    F.ok(owner:needs_paint(), 'paint-only change is paint dirty')
    owner:layout()
    F.eq(owner.root.size, Size(20, 12), 'paint-only change keeps size')
end)

F.test('a rebuilt Text without paint options restores the default paint', function()
    local owner, binding = mount(Text('x', {
        text_paint = TextPaint({ anchor = Anchor.CENTER }),
    }))
    binding:set_root_widget(Text('x'))
    F.eq(owner.root.text_paint.anchor, Anchor.TOP_LEFT, 'default anchor restored')
    F.ok(not owner:needs_layout(), 'restoring paint does not relayout')
end)

--== element reuse =========================================================

F.section('widget: element reuse')

F.test('reuses the element and render object when the widget type matches', function()
    local owner, binding = mount(SizedBox({ width = 10, height = 10 }))
    local element = binding.root_element
    local render_object = element.render_object
    binding:set_root_widget(SizedBox({ width = 30, height = 20 }))
    owner:layout()
    F.ok(binding.root_element == element, 'element reused')
    F.ok(binding.root_element.render_object == render_object, 'render object reused')
    F.ok(owner.root.size == Size(30, 20), 'size updated in place')
end)

F.test('recreates the element when the widget class changes', function()
    local owner, binding = mount(SizedBox({ width = 10, height = 10 }))
    local element = binding.root_element
    binding:set_root_widget(Container({ width = 10, height = 10 }))
    owner:layout()
    F.ok(binding.root_element ~= element, 'new element')
end)

F.test('a changed key forces a new element, an equal key does not', function()
    local owner, binding = mount(SizedBox({ key = Key('a'), width = 10, height = 10 }))
    local element = binding.root_element
    binding:set_root_widget(SizedBox({ key = Key('b'), width = 10, height = 10 }))
    F.ok(binding.root_element ~= element, 'key changed -> new element')
    local relocated = binding.root_element
    binding:set_root_widget(SizedBox({ key = Key('b'), width = 12, height = 10 }))
    F.ok(binding.root_element == relocated, 'equal key -> reused')
end)

F.test('the same widget instance skips rebuilding its subtree', function()
    local builds = 0
    local Probe = std.class.new('test.IdentityProbe', { widget_mod.StatelessWidget })
    function Probe:build()
        builds = builds + 1
        return Text('identity')
    end

    local child = Probe()
    local Host = std.class.new('test.IdentityHost', { widget_mod.StatelessWidget })
    function Host:build()
        return child
    end

    local owner, binding = mount(Host())
    F.eq(builds, 1, 'initial child build')
    binding:set_root_widget(Host())
    F.eq(builds, 1, 'identical child widget is reused')
    owner:layout()
end)

--== multi child ===========================================================

F.section('widget: multi-child')

F.test('keeps render children in order across rebuilds', function()
    local owner, binding = mount(Column({
        children = { SizedBox({ width = 10, height = 10 }), SizedBox({ width = 20, height = 10 }) },
    }), Constraints.loose(100, 100))
    F.eq(#owner.root:children(), 2, 'two children')
    binding:set_root_widget(Column({
        children = {
            SizedBox({ width = 10, height = 10 }),
            SizedBox({ width = 20, height = 10 }),
            SizedBox({ width = 30, height = 10 }),
        },
    }))
    owner:layout()
    F.eq(#owner.root:children(), 3, 'added child')
    F.close(owner.root:children()[3].size.width, 30, 'order preserved')
end)

F.test('keyed children keep their Element state when reordered', function()
    local ItemState = std.class.new('test.KeyedItemState', { state_mod.State })
    function ItemState:init_state()
        self.initial_label = self.widget.label
    end
    function ItemState:build()
        return Text(self.initial_label)
    end

    local Item = std.class.new('test.KeyedItem', { widget_mod.StatefulWidget })
    function Item:__init(options)
        self.key = options and options.key
        self.label = options.label
    end
    function Item:create_state()
        return ItemState()
    end

    local owner, binding = mount(Column({
        children = {
            Item({ key = Key('a'), label = 'A' }),
            Item({ key = Key('b'), label = 'B' }),
        },
    }), Constraints.loose(100, 100))
    binding:set_root_widget(Column({
        children = {
            Item({ key = Key('b'), label = 'B2' }),
            Item({ key = Key('a'), label = 'A2' }),
        },
    }))
    owner:layout()
    local children = owner.root:children()
    F.eq(children[1].paragraph.text, 'B', 'B state moved with key')
    F.eq(children[2].paragraph.text, 'A', 'A state moved with key')
end)

F.test('Expanded contributes parent data to its child render object', function()
    local owner = mount(Row({
        children = { Text('a'), Expanded(Text('b')), Text('c') },
    }), Constraints.tight(120, 20))
    local children = owner.root:children()
    F.eq(#children, 3, 'three children')
    F.eq(children[2].parent_data.flex, 1, 'flex applied to the middle child')
    F.ok(children[2].size.width > children[1].size.width, 'middle child grew')
end)

F.test('Stack overlays and aligns children', function()
    local owner = mount(Stack({
        children = { SizedBox({ width = 40, height = 40 }), SizedBox({ width = 10, height = 10 }) },
    }), Constraints.loose(100, 100))
    F.ok(owner.root.size == Size(40, 40), 'sized to the biggest child')
    -- `Stack.alignment` defaults to topStart, not centre.
    F.ok(owner.root:children()[2].parent_data.offset == Offset(0, 0), 'smaller child at topStart')
end)

F.test('Stack honours an explicit alignment', function()
    local owner = mount(Stack({
        alignment = Offset(0.5, 0.5),
        children = { SizedBox({ width = 40, height = 40 }), SizedBox({ width = 10, height = 10 }) },
    }), Constraints.loose(100, 100))
    F.ok(owner.root:children()[2].parent_data.offset == Offset(15, 15), 'smaller child centered')
end)

--== state =================================================================

F.section('widget: state')

local CounterState = std.class.new('test.CounterState', { state_mod.State })
function CounterState:init_state()
    self.n = 0
end
function CounterState:build()
    return Text('n=' .. self.n)
end

local Counter = std.class.new('test.Counter', { widget_mod.StatefulWidget })
function Counter:create_state()
    return CounterState()
end

F.test('set_state rebuilds the subtree but keeps the render object', function()
    local owner, binding = mount(Counter())
    local element = binding.root_element
    local text_render = owner.root
    F.eq(text_render.paragraph.text, 'n=0', 'initial build')

    element.state:set_state(function()
        element.state.n = 7
    end)
    F.ok(binding.build_owner:has_dirty(), 'element marked dirty')
    binding:flush_build()
    owner:layout()

    F.ok(binding.root_element == element, 'element kept')
    F.ok(owner.root == text_render, 'render object kept')
    F.eq(text_render.paragraph.text, 'n=7', 'rebuilt with new state')
end)

F.test('a dirty child is not rebuilt twice when its parent is also dirty', function()
    local builds = 0
    local Probe = std.class.new('test.Probe', { widget_mod.StatelessWidget })
    function Probe:build()
        builds = builds + 1
        return Text('x')
    end

    local HostState = std.class.new('test.HostState', { state_mod.State })
    function HostState:init_state()
        self.n = 0
    end
    function HostState:build()
        return Column({ children = { Probe(), Probe() } })
    end

    local Host = std.class.new('test.Host', { widget_mod.StatefulWidget })
    function Host:create_state()
        return HostState()
    end

    local owner, binding = mount(Host())
    F.eq(builds, 2, 'each probe built once on mount')

    local column_element = binding.root_element.child
    column_element.children[1]:mark_dirty()
    binding.root_element.state:set_state()
    binding:flush_build()
    F.eq(builds, 4, 'each probe rebuilt exactly once')
end)

F.test('unmounting disposes state', function()
    local disposed = false
    local Disposable = std.class.new('test.Disposable', { state_mod.State })
    function Disposable:init_state()
        self.n = 0
    end
    function Disposable:dispose()
        disposed = true
    end
    function Disposable:build()
        return Text('x')
    end
    local W = std.class.new('test.DisposableWidget', { widget_mod.StatefulWidget })
    function W:create_state()
        return Disposable()
    end

    local owner, binding = mount(W())
    binding:set_root_widget(SizedBox({ width = 1, height = 1 }))
    F.ok(disposed, 'state disposed on replacement')
end)

F.test('set_state refuses an unmounted State', function()
    ---@type State?
    local state
    local UnmountedState = std.class.new('test.UnmountedState', { state_mod.State })
    function UnmountedState:build()
        return Text('x')
    end
    local W = std.class.new('test.UnmountedStateWidget', { widget_mod.StatefulWidget })
    function W:create_state()
        state = UnmountedState()
        return state
    end

    local _, binding = mount(W())
    binding:set_root_widget(SizedBox({ width = 1, height = 1 }))
    assert(state)
    local changed = state:set_state(function()
        state.changed = true
    end)
    F.ok(not changed, 'disposed state rejected')
    F.ok(not state.changed, 'callback was not run')
end)
