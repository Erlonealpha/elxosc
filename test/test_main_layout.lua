-- N1 application composition: one DefaultApp with stable Main, Extension and
-- WindowLayer boundaries.  The old nine-region scaffold is intentionally gone.

---@diagnostic disable: undefined-field, inject-field, need-check-nil, unused, generic-constraint-mismatch

local F = require('framework')
local std = require('elxlibs.std')

local constraints_mod = require('layout.constraints')
local text_layout = require('text.text_layout')
local render_owner = require('render.render_owner')
local binding_mod = require('widget.binding')
local slot_mod = require('widget.slot')
local basic_widgets = require('widget.widgets.basic')
local layout_widgets = require('widget.widgets.layout')
local widget_mod = require('widget.widget')
local state_mod = require('widget.state')
local frame_clock_mod = require('scheduler.frame_clock')
local scheduler_mod = require('scheduler.scheduler')
local app_mod = require('widget.app')
local ambient_mod = require('widget.ambient')
local actions_mod = require('widget.actions')
local visibility_mod = require('widget.visibility')
local main_layout = require('main_layout')
local navigation_mod = require('widget.navigation')

local Constraints = constraints_mod.Constraints
local RenderOwner = render_owner.RenderOwner
local WidgetBinding = binding_mod.WidgetBinding
local Text = basic_widgets.Text
local Column = layout_widgets.Column
local StatelessWidget = widget_mod.StatelessWidget
local StatefulWidget = widget_mod.StatefulWidget
local State = state_mod.State
local WidgetsApp = app_mod.WidgetsApp
local DefaultApp = app_mod.DefaultApp
local Main = app_mod.Main
local ThemeData = ambient_mod.ThemeData
local DisplaySnapshot = ambient_mod.DisplaySnapshot
local HostActions = actions_mod.HostActions
local SlotWrap = slot_mod.SlotWrap
local ContributionRegistry = slot_mod.ContributionRegistry
local CompositionAssembler = slot_mod.CompositionAssembler
local Navigator = navigation_mod.Navigator
local AutoHide = visibility_mod.AutoHide
local AutoHideController = visibility_mod.AutoHideController
local FrameClock = frame_clock_mod.FrameClock
local Scheduler = scheduler_mod.Scheduler

local FixedLayout = std.class.new('test.mainlayout.FixedLayout', { text_layout.TextLayout })
function FixedLayout:line_width(line, style)
    return #line * style.font_size * 0.5
end
text_layout.set_default(FixedLayout())

local ManualClock = std.class.new('test.mainlayout.ManualClock', { FrameClock })
function ManualClock:__init()
    self.time = 0
    self.pending = false
end
function ManualClock:now()
    return self.time
end
function ManualClock:request_frame()
    self.pending = true
end
function ManualClock:tick(dt)
    self.time = self.time + dt
    if self.pending then
        self.pending = false
        self:_emit()
    end
end

local function mount(widget, scheduler)
    local owner = RenderOwner()
    local binding = WidgetBinding.ensure_initialized():attach(widget, owner, scheduler)
    owner:set_viewport(Constraints.tight(300, 180))
    owner:layout()
    return owner, binding
end

local function find_widget_element(element, widget_class)
    if element == nil then
        return nil
    end
    if element.widget and element.widget.__class == widget_class then
        return element
    end
    for _, child in ipairs(element:element_children()) do
        local found = find_widget_element(child, widget_class)
        if found then
            return found
        end
    end
    return nil
end

local function count_widget_elements(element, widget_class)
    if element == nil then
        return 0
    end
    local count = element.widget and element.widget.__class == widget_class and 1 or 0
    for _, child in ipairs(element:element_children()) do
        count = count + count_widget_elements(child, widget_class)
    end
    return count
end

local function collect_slot_ids(widget, ids)
    if widget.__class == SlotWrap then
        ids[widget.spec.id] = (ids[widget.spec.id] or 0) + 1
    end
    if type(widget.child_widgets) ~= 'function' then
        return
    end
    for _, child in ipairs(widget:child_widgets()) do
        collect_slot_ids(child, ids)
    end
end

F.section('main layout: DefaultApp composition')

F.test('the entry point builds one DefaultApp without the old grid contract', function()
    local root = main_layout.build_app(Text('extension'))
    F.eq(root.__class, DefaultApp, 'DefaultApp is the content root')
    F.ok(main_layout.SLOT == nil, 'old nine-region SLOT table is removed')
    F.eq(#root:child_widgets(), 3, 'main, extension and window layer are explicit children')
end)

F.test('the production description exposes one Extension content boundary', function()
    local ids = {}
    collect_slot_ids(main_layout.build_app_description(Text('extension')), ids)
    F.eq(ids['app.extension'], 1, 'one extension slot is declared')
    F.eq(next(ids, 'app.extension'), nil, 'no shell or root replacement slots are declared')

    local Extension = std.class.new('test.mainlayout.ExtensionBoundary', { StatelessWidget })
    function Extension:build()
        return Text('extension-boundary')
    end

    local registry = ContributionRegistry()
    for _, id in ipairs({
        'top_left', 'top', 'top_right',
        'left', 'middle', 'right',
        'bottom_left', 'bottom', 'bottom_right',
    }) do
        registry:add(id, Text('old-grid'), { op = 'set' }, 'old-grid')
    end
    registry:add('app.extension', Extension(), { op = 'set' }, 'extension')

    local assembler = CompositionAssembler(registry:seal())
    local root = assembler:assemble(main_layout.build_app_description(Text('default')))
    F.eq(#assembler.diagnostics, 9, 'all old grid ids are rejected')
    local _, binding = mount(root)
    F.eq(count_widget_elements(binding.root_element, Extension), 1,
        'extension content has one mounted owner')
end)

F.test('WindowLayer owns one empty Navigator when no initial Page is provided', function()
    local root = main_layout.build_app(Text('extension'))
    local _, binding = mount(root)
    local navigator = find_widget_element(binding.root_element, Navigator)
    F.ok(navigator ~= nil, 'WindowLayer contains the Navigator runtime')
    if navigator then
        F.eq(#navigator.state.routes, 0, 'empty WindowLayer has no current Page')
    end
end)

F.test('WidgetsApp exposes stable theme, display, text and action ambients', function()
    local Reader = std.class.new('test.mainlayout.AmbientReader', { StatelessWidget })
    function Reader:build(context)
        local theme = ambient_mod.Theme.of(context)
        local display = ambient_mod.DisplayScope.of(context)
        local style = ambient_mod.DefaultTextStyle.of(context)
        local actions = HostActions.maybe_of(context)
        return Text(string.format('%g/%g/%g/%s',
            theme.data.scale, display.snapshot.width, style.style.font_size,
            actions and 'actions' or 'no-actions'))
    end

    local owner = mount(WidgetsApp({
        theme = ThemeData({ scale = 1.25 }),
        display = DisplaySnapshot({ width = 300, height = 180, initialized = true }),
        actions = HostActions({ play_pause = function() end }),
        child = Reader(),
    }))
    F.eq(owner.root.paragraph.text, '1.25/300/14/actions', 'ambient values reach descendants')
end)

local ProbeState = std.class.new('test.mainlayout.ProbeState', { State })
function ProbeState:init_state()
    self.mounts = (self.mounts or 0) + 1
    self.disposed = false
end
function ProbeState:dispose()
    self.disposed = true
end
function ProbeState:build()
    return Text('extension-state')
end

local Probe = std.class.new('test.mainlayout.Probe', { StatefulWidget })
function Probe:create_state()
    return ProbeState()
end

F.test('hiding Main keeps the Extension entry mounted and rendered', function()
    local owner, binding = mount(main_layout.build_app(Probe()))
    local default_element = find_widget_element(binding.root_element, DefaultApp)
    F.ok(default_element ~= nil, 'DefaultApp element is mounted')
    if default_element == nil then
        return
    end
    local extension_element = find_widget_element(binding.root_element, Probe)
    F.ok(extension_element ~= nil, 'Extension element is mounted')
    if extension_element == nil then
        return
    end
    local extension_state = extension_element.state
    default_element.state:hide_main()
    binding:flush_build()
    owner:layout()
    F.ok(extension_state:is_mounted(), 'Extension State survives Main visibility changes')
    F.ok(not extension_state.disposed, 'Extension State is not disposed')
    F.eq(owner.root ~= nil, true, 'single logical render root remains')
end)

F.test('Main has a configurable uniform scale and explicit player actions', function()
    local called = 0
    local actions = HostActions({ play_pause = function() called = called + 1 end })
    local owner = mount(WidgetsApp({
        theme = ThemeData({ scale = 1.1 }),
        actions = actions,
        child = Main({ title = 'Player' }),
    }))
    F.ok(owner.root ~= nil, 'Main produces a render tree')
    F.ok(owner.root.size.width == 300 and owner.root.size.height == 180, 'Main fills the viewport')
    actions:play_pause()
    F.eq(called, 1, 'actions are explicit callbacks')
end)

F.test('AutoHide uses the frame clock and activity restores Main visibility', function()
    local clock = ManualClock()
    local scheduler = Scheduler(clock)
    local controller = AutoHideController()
    mount(AutoHide({ controller = controller, timeout = 0.5, child = Text('main') }), scheduler)
    F.ok(controller.visible, 'AutoHide starts visible')
    clock:tick(0.1)
    clock:tick(0.5)
    F.ok(not controller.visible, 'timeout hides the entry')
    controller:activity()
    F.ok(controller.visible, 'activity restores the entry')
    scheduler:dispose()
end)
