-- The mpv app wiring: frame clock, overlay presenter, widget binding, input.

-- `host/*` requires `mp`; the suite installs the stub from `test/mp_stub.lua`.
-- See the note in test_widget.lua: the `std.class` / optional-ownership
-- diagnostics are disabled across the suite.
---@diagnostic disable: undefined-field, inject-field, need-check-nil, generic-constraint-mismatch, preferred-local-alias, unused

local F = require('framework')
local std = require('elxlibs.std')

local mp_stub = require('mp_stub')
mp_stub.install()

local fake = mp_stub.fake

local color = require('foundation.color')
local text_style = require('text.text_style')
local mpv_app = require('host.mpv_app')
local mpv_define = require('host.mpv_define')
local demo_mod = require('demo')
local layout_widgets = require('widget.widgets.layout')
local basic_widgets = require('widget.widgets.basic')
local bind_mod = require('widget.bind')
local state_mod = require('widget.state')
local widget_mod = require('widget.widget')

local Color = color.Color
local TextStyle = text_style.TextStyle
local MpDefine = mpv_define.MpDefine
local Slot = bind_mod.Slot
local State = state_mod.State
local StatefulWidget = widget_mod.StatefulWidget
local Column = layout_widgets.Column
local Text = basic_widgets.Text
local Button = basic_widgets.Button
local Demo = demo_mod.Demo

---@return Widget
local function scaffold()
    return Column({ children = { Slot('slot'), Text('body', {
        style = TextStyle({ font_size = 16, color = Color.rgba255(0xFF, 0xFF, 0xFF) }),
    }) } })
end

--== frame clock ===========================================================

F.section('host app: frame clock')

F.test('frames are rate limited and coalesced', function()
    mp_stub.reset()
    local clock = mpv_app.MpFrameClock(1 / 60)
    clock:request_frame()
    clock:request_frame()
    F.eq(#fake.timeouts, 1, 'one timer for two requests')
end)

F.test('the display fps sets the delay', function()
    mp_stub.reset()
    fake.fps = 30
    local app = mpv_app.App(scaffold())
    F.close(app.clock.delay, 1 / 30, 'delay follows display-fps')
end)

--== presenter =============================================================

F.section('host app: presenter')

F.test('an identical frame is not pushed twice', function()
    mp_stub.reset()
    local app = mpv_app.App(scaffold())
    fake.timeouts = {}
    app:render()
    local updates = fake.overlay.updates
    app:render()
    F.eq(fake.overlay.updates, updates, 'second identical frame skipped')
end)

F.test('the overlay carries the ASS text and the resolution', function()
    mp_stub.reset()
    local app = mpv_app.App(scaffold())
    app:render()
    F.eq(fake.overlay.format, 'ass-events', 'format')
    F.eq(fake.overlay.res_x, 1280, 'res_x from get_osd_size')
    F.eq(fake.overlay.res_y, 720, 'res_y from get_osd_size')
    F.ok(fake.overlay.data ~= nil and #fake.overlay.data > 0, 'ASS payload emitted')
end)

F.test('interactive input installs a precise area and consumes double-click', function()
    mp_stub.reset()
    local clicks = 0
    local app = mpv_app.App(Button({
        label = 'OK',
        on_click = function() clicks = clicks + 1 end,
    }))
    app:render()

    local binding = fake.binding_sections['elxosc-input']
    F.ok(binding ~= nil, 'interactive section is defined')
    ---@type table?
    local double_binding
    ---@type table[]
    local entries = binding.list
    for _, entry in ipairs(entries) do
        if entry[1] == 'mbtn_left_dbl' then
            double_binding = entry
        end
    end
    F.ok(double_binding ~= nil, 'left double-click is claimed by the UI section')
    local double_callback = double_binding[2] --[[@as fun()]]
    double_callback()
    F.eq(clicks, 0, 'double-click does not synthesize a button click')

    local areas = fake.mouse_areas['elxosc-input']
    F.ok(areas ~= nil and #areas >= 2, 'input area is cleared and then installed')
    local installed = areas[#areas]
    F.ok(installed.x1 > installed.x0 and installed.y1 > installed.y0,
        'interactive area has positive bounds')
end)

F.test('separate interactive regions use separate mpv sections', function()
    mp_stub.reset()
    local app = mpv_app.App(Column({
        children = {
            Button({ label = 'one', on_click = function() end }),
            Button({ label = 'two', on_click = function() end }),
        },
    }))
    app:render()

    local first_history = fake.mouse_areas['elxosc-input']
    local second_history = fake.mouse_areas['elxosc-input-2']
    F.ok(first_history ~= nil and second_history ~= nil,
        'each interactive region has its own section')
    if first_history == nil or second_history == nil then
        return
    end
    local first = first_history[#first_history]
    local second = second_history[#second_history]
    F.ok(first.x1 > first.x0 and first.y1 > first.y0, 'first area has positive bounds')
    F.ok(second.x1 > second.x0 and second.y1 > second.y0, 'second area has positive bounds')
    F.ok(first.y0 < second.y0,
        'separate areas preserve the controls\' relative positions')
    F.ok(fake.bindings_enabled_sections['elxosc-input'] ~= nil,
        'first input section is enabled')
    F.ok(fake.bindings_enabled_sections['elxosc-input-2'] ~= nil,
        'second input section is enabled')
end)

F.test('a passive root leaves default mpv input available', function()
    mp_stub.reset()
    local app = mpv_app.App(scaffold())
    app:render()
    F.ok(fake.binding_sections['elxosc-input'] ~= nil, 'input section is defined once')
    F.ok(fake.bindings_enabled_sections['elxosc-input'] == nil,
        'passive scaffold does not enable input section')
    local areas = fake.mouse_areas['elxosc-input']
    local cleared = areas and areas[#areas]
    F.ok(cleared ~= nil and cleared.x0 == cleared.x1 and cleared.y0 == cleared.y1,
        'passive scaffold clears its input area')
end)

F.test('display resize schedules a fresh layout and input-area update', function()
    mp_stub.reset()
    local app = mpv_app.App(Button({ label = 'OK', on_click = function() end }))
    app:render()
    mp_stub.pump()
    fake.timeouts = {}
    fake.osd_width, fake.osd_height = 640, 360
    for _, event in ipairs(fake.events) do
        if event.name == 'osd-dimensions' then
            event.cb(nil, nil)
        end
    end
    F.eq(app.display.width, 640, 'display width updated')
    F.eq(app.display.height, 360, 'display height updated')
    F.ok(#fake.timeouts > 0, 'resize requests a frame')
    mp_stub.pump()
    local areas = fake.mouse_areas['elxosc-input']
    local installed = areas[#areas]
    F.ok(installed.x1 > installed.x0 and installed.y1 > installed.y0,
        'input area remains installed after resize')
end)

F.test('root replacement cancels capture and clears old areas', function()
    mp_stub.reset()
    local app = mpv_app.App(Button({ label = 'OK', on_click = function() end }))
    app:render()
    fake.mouse = { x = 5, y = 5, hover = true }
    for _, event in ipairs(fake.events) do
        if event.name == 'mouse-pos' then event.cb(nil, fake.mouse) end
    end
    fake.bindings.list[1][3]()
    F.ok(fake.bindings_enabled_sections['elxosc-input'] ~= nil, 'capture starts')
    app:set_root_widget(scaffold())
    app.binding:flush_build()
    app:render()
    local areas = fake.mouse_areas['elxosc-input']
    local cleared = areas[#areas]
    F.ok(fake.bindings_enabled_sections['elxosc-input'] == nil,
        'old input section is disabled')
    F.ok(cleared.x0 == cleared.x1 and cleared.y0 == cleared.y1,
        'old area is cleared')
end)

F.test('shutdown clears input sections and areas', function()
    mp_stub.reset()
    local app = mpv_app.App(Button({ label = 'OK', on_click = function() end }))
    app:render()
    fake.log['event:shutdown']()
    local areas = fake.mouse_areas['elxosc-input']
    local cleared = areas[#areas]
    F.ok(fake.bindings_enabled_sections['elxosc-input'] == nil,
        'input section disabled on shutdown')
    F.ok(cleared.x0 == cleared.x1 and cleared.y0 == cleared.y1,
        'input area cleared on shutdown')
end)

F.test('the demo exposes anchors, nominal icons and static animation output', function()
    mp_stub.reset()
    local app = mpv_app.App(Demo())
    app:render()
    F.contains(fake.overlay.data, '\\an5', 'center text anchor')
    F.contains(fake.overlay.data, '\\an3', 'bottom-right text anchor')
    F.contains(fake.overlay.data, '\\fnMaterial Symbols Rounded', 'icon font')
    F.contains(fake.overlay.data, 'Frame-clock OffsetBox', 'paint-only offset demo label')
end)

F.test('the demo exposes finite scale box and clip output', function()
    mp_stub.reset()
    local app = mpv_app.App(Demo())
    app:render()
    F.contains(fake.overlay.data, 'Scale boxes', 'scale box demo label')
    F.contains(fake.overlay.data, '\\fscx', 'finite text scale output')
    F.contains(fake.overlay.data, '\\clip', 'fitted box clip output')
    F.contains(fake.overlay.data, 'cover crop', 'cover example output')
    F.contains(fake.overlay.data, 'TransformBox', 'paint-only transform output')
    F.contains(fake.overlay.data, 'LayoutScaleBox', 'layout scale output')
    F.contains(fake.overlay.data, 'Scale tap', 'animated scale button output')
end)

--== widget binding ========================================================

F.section('host app: widget binding')

F.test('build() returns a widget and the app builds the render tree', function()
    mp_stub.reset()
    local app = mpv_app.App(scaffold())
    F.ok(app.owner.root ~= nil, 'the binding mounted a render root')
    F.eq(#app.owner.root:children(), 1, 'the empty slot contributed nothing')
end)

F.test('set_root_widget swaps the tree', function()
    mp_stub.reset()
    local app = mpv_app.App(scaffold())
    app:set_root_widget(Column({ children = { Text('one') } }))
    app.binding:flush_build()
    app.owner:layout()
    F.eq(app.owner.root:children()[1].paragraph.text, 'one', 'root replaced')
end)

F.test('a set_state rebuild lands in the next frame', function()
    mp_stub.reset()

    local CounterState = std.class.new('test.hostApp.CounterState', { State })
    function CounterState:__init()
        self.value = 0
    end
    function CounterState:build()
        return Text('v' .. self.value)
    end

    local Counter = std.class.new('test.hostApp.Counter', { StatefulWidget })
    function Counter:create_state()
        return CounterState()
    end

    local app = mpv_app.App(Column({ children = { Counter() } }))
    -- reach the live state through the element tree
    local element = app.binding.root_element
    local child = element:element_children()[1]
    child.state:set_state(function()
        child.state.value = 7
    end)

    app.binding:flush_build()
    app.owner:layout()
    F.eq(app.owner.root:children()[1].paragraph.text, 'v7', 'rebuilt with the new state')
end)

F.test('host input bindings deliver a left click to Button', function()
    mp_stub.reset()
    local clicks = 0
    local app = mpv_app.App(Button({ label = 'OK', on_click = function() clicks = clicks + 1 end }))
    app:render()
    fake.mouse = { x = 5, y = 5, hover = true }
    for _, event in ipairs(fake.events) do
        if event.name == 'mouse-pos' then
            event.cb(nil, fake.mouse)
        end
    end
    F.ok(fake.bindings_enabled ~= nil, 'button enables mouse bindings')
    fake.bindings.list[1][3]()
    fake.bindings.list[1][2]()
    F.eq(clicks, 1, 'host delivered click')
end)

F.test('host capture keeps the press routed after leaving the button', function()
    mp_stub.reset()
    local clicks = 0
    local app = mpv_app.App(Button({ label = 'OK', on_click = function() clicks = clicks + 1 end }))
    app:render()
    fake.mouse = { x = 5, y = 5, hover = true }
    for _, event in ipairs(fake.events) do
        if event.name == 'mouse-pos' then event.cb(nil, fake.mouse) end
    end
    local bindings = fake.bindings.list
    bindings[1][3]()
    fake.mouse = { x = 5000, y = 5000, hover = true }
    for _, event in ipairs(fake.events) do
        if event.name == 'mouse-pos' then event.cb(nil, fake.mouse) end
    end
    bindings[1][2]()
    F.eq(clicks, 0, 'release outside does not click')
end)

--== the whole entry point =================================================

F.section('host app: define window over a live app')

F.test('binds are applied to a fresh scaffold and mounted', function()
    mp_stub.reset()
    local define = MpDefine({ builtins = { Text = Text } })
    define:listen()
    fake.log['define_start']()
    fake.log['define']('scope_a', "bind('slot', Text('bound'))")
    fake.log['define_end']()

    local app = mpv_app.App(scaffold())
    app:set_root_widget(define:apply(scaffold()))
    app.binding:flush_build()
    app.owner:layout()

    F.eq(app.owner.root:children()[1].paragraph.text, 'bound', 'the bound widget rendered')
end)

F.test('an unbound slot costs no render node', function()
    mp_stub.reset()
    local define = MpDefine()
    define:listen()
    local app = mpv_app.App(define:apply(scaffold()))
    app.binding:flush_build()
    app.owner:layout()
    F.eq(#app.owner.root:children(), 1, 'only the body remains')
end)
