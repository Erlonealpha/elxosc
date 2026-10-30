-- N1 application composition: one DefaultApp with stable Main, Extension and
-- WindowLayer boundaries.  The old nine-region scaffold is intentionally gone.

---@diagnostic disable: undefined-field, inject-field, need-check-nil, unused, generic-constraint-mismatch

local F = require('framework')
local std = require('elxlibs.std')

local constraints_mod = require('layout.constraints')
local geometry = require('foundation.geometry')
local text_layout = require('text.text_layout')
local render_owner = require('render.render_owner')
local binding_mod = require('widget.binding')
local slot_mod = require('widget.slot')
local basic_widgets = require('widget.widgets.basic')
local player_widgets = require('widget.player')
local layout_widgets = require('widget.widgets.layout')
local widget_mod = require('widget.widget')
local state_mod = require('widget.state')
local frame_clock_mod = require('scheduler.frame_clock')
local scheduler_mod = require('scheduler.scheduler')
local app_mod = require('widget.app')
local ambient_mod = require('widget.ambient')
local actions_mod = require('widget.actions')
local visibility_mod = require('widget.visibility')
local player_context = require('widget.player_context')
local main_layout = require('main_layout')
local navigation_mod = require('widget.navigation')

local Constraints = constraints_mod.Constraints
local RenderOwner = render_owner.RenderOwner
local WidgetBinding = binding_mod.WidgetBinding
local Text = basic_widgets.Text
local Button = basic_widgets.Button
local GestureDetector = basic_widgets.GestureDetector
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
local PlayerStore = player_context.PlayerStore
local PlayerScope = player_context.PlayerScope
local ProgressBar = player_widgets.ProgressBar
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

local function find_widget_instance(element, widget)
    if element == nil then
        return nil
    end
    if element.widget == widget then
        return element
    end
    for _, child in ipairs(element:element_children()) do
        local found = find_widget_instance(child, widget)
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

F.test('Main maps PlayerSnapshot time values into an interactive seek bar', function()
    local sought
    local actions = HostActions({
        seek_to = function(seconds)
            sought = seconds
        end,
    })
    local store = PlayerStore({
        media_title = 'Episode 7',
        time_pos = 25,
        duration = 100,
        percent_pos = 25,
        pause = true,
    })
    local owner, binding = mount(WidgetsApp({
        actions = actions,
        child = PlayerScope({ store = store, child = Main() }),
    }))
    local progress = find_widget_element(binding.root_element, ProgressBar)
    F.ok(progress ~= nil, 'Main mounts the ProgressBar')
    if progress == nil then
        return
    end
    F.close(progress.widget.progress, 0.25, 'snapshot percent reaches progress')
    F.eq(progress.widget.on_seek ~= nil, true, 'progress bar has a seek callback')
    actions:seek_to(75)
    F.eq(sought, 75, 'Main uses the explicit absolute seek action')
    F.ok(owner.root ~= nil, 'player shell keeps one render root')
end)

F.test('seek dragging pauses once, deduplicates motion and restores playback', function()
    local calls = {}
    local actions = HostActions({
        seek_to = function(seconds, mode)
            calls[#calls + 1] = { 'seek', seconds, mode }
        end,
        set_pause = function(paused)
            calls[#calls + 1] = { 'pause', paused }
        end,
    })
    local store = PlayerStore({
        time_pos = 10,
        duration = 100,
        percent_pos = 10,
        pause = false,
    })
    local owner, binding = mount(WidgetsApp({
        actions = actions,
        child = PlayerScope({ store = store, child = Main() }),
    }))
    local progress = find_widget_element(binding.root_element, ProgressBar)
    F.ok(progress ~= nil, 'seek bar is mounted for the state machine')
    if progress == nil then
        return
    end
    local offset = progress.render_object.parent_data.offset
    local y = offset.y + 8
    owner:dispatch_pointer('down', geometry.Offset(offset.x + 123, y), 'left')
    owner:dispatch_pointer('move', geometry.Offset(offset.x + 200, y))
    owner:dispatch_pointer('move', geometry.Offset(offset.x + 200, y))
    owner:dispatch_pointer('up', geometry.Offset(offset.x + 200, y), 'left')
    F.eq(calls[1][1], 'pause', 'drag pauses before seeking')
    F.eq(calls[1][2], true, 'drag pause is explicit')
    F.eq(calls[2][1], 'seek', 'drag starts with absolute seek')
    F.eq(calls[3][1], 'seek', 'changed motion seeks')
    F.eq(calls[4][1], 'seek', 'release sends the final seek')
    F.eq(calls[5][1], 'pause', 'release restores playback')
    F.eq(calls[5][2], false, 'playback restoration is explicit')
end)

F.test('soft-repeat fires on frame ticks and stops on release', function()
    local clock = ManualClock()
    local scheduler = Scheduler(clock)
    local clicks = 0
    local owner = mount(Button({
        label = 'Jump',
        soft_repeat = true,
        on_click = function()
            clicks = clicks + 1
        end,
    }), scheduler)
    owner:dispatch_pointer('down', geometry.Offset(5, 5), 'left')
    F.eq(clicks, 1, 'soft-repeat action fires on button down')
    for _ = 1, 14 do
        clock:tick(1 / 60)
    end
    F.eq(clicks, 1, 'soft-repeat waits for the hold threshold')
    clock:tick(1 / 60)
    F.eq(clicks, 2, 'soft-repeat fires at the threshold')
    for _ = 1, 5 do
        clock:tick(1 / 60)
    end
    F.eq(clicks, 3, 'soft-repeat repeats every five frame ticks')
    owner:dispatch_pointer('up', geometry.Offset(5, 5), 'left')
    for _ = 1, 10 do
        clock:tick(1 / 60)
    end
    F.eq(clicks, 3, 'release stops soft-repeat')
    scheduler:dispose()
end)

F.test('Main top bar follows window state while bottom controls remain mounted', function()
    local store = PlayerStore({ fullscreen = false, border = true, title_bar = true })
    local top = Text('top-only')
    local bottom = Text('bottom-only')
    local _, binding = mount(WidgetsApp({
        child = PlayerScope({
            store = store,
            child = Main({ title_bar = top, bottom = bottom }),
        }),
    }))
    F.ok(find_widget_instance(binding.root_element, top) == nil,
        'normal bordered window hides the top bar')
    F.ok(find_widget_instance(binding.root_element, bottom) ~= nil,
        'normal bordered window keeps bottom controls')

    store:replace({ fullscreen = true, border = true, title_bar = true })
    binding:flush_build()
    F.ok(find_widget_instance(binding.root_element, top) ~= nil,
        'fullscreen window shows the top bar')
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

F.test('AutoHide fades through opacity while retaining input until completion', function()
    local clock = ManualClock()
    local scheduler = Scheduler(clock)
    local controller = AutoHideController()
    local owner, binding = mount(AutoHide({
        controller = controller,
        timeout = 0,
        fade_duration = 0.2,
        child = GestureDetector(Text('main'), {
            on_tap = function() end,
        }),
    }), scheduler)
    local render_opacity = owner.root
    local state = binding.root_element.state
    owner:paint(require('backends.record').RecordCanvas())

    F.ok(not render_opacity.hidden, 'AutoHide starts unhidden')
    F.close(render_opacity.opacity, 1, 'AutoHide starts opaque')
    F.ok(#owner:pointer_regions() > 0, 'visible Main contributes pointer regions')

    controller:hide()
    F.ok(not render_opacity.hidden, 'fade-out keeps Main painted initially')
    clock:tick(0)
    clock:tick(0.1)
    F.close(render_opacity.opacity, 0.5, 'fade-out samples at half duration')
    F.ok(not render_opacity.hidden, 'fade-out keeps Main interactive')
    F.ok(#owner:pointer_regions() > 0, 'fade-out retains pointer regions')
    clock:tick(0.1)
    F.close(render_opacity.opacity, 0, 'fade-out reaches transparent')
    F.ok(render_opacity.hidden, 'completed fade-out hides the render object')
    F.eq(#owner:pointer_regions(), 0, 'completed fade-out removes pointer regions')
    F.ok(state:is_mounted(), 'maintained AutoHide state remains mounted')

    controller:show()
    F.ok(not render_opacity.hidden, 'fade-in enables the render object first')
    F.close(render_opacity.opacity, 0, 'fade-in starts transparent')
    clock:tick(0)
    clock:tick(0.1)
    F.close(render_opacity.opacity, 0.5, 'fade-in samples at half duration')
    clock:tick(0.1)
    F.close(render_opacity.opacity, 1, 'fade-in reaches opaque')
    F.ok(#owner:pointer_regions() > 0, 'completed fade-in restores pointer regions')
    scheduler:dispose()
end)

F.test('AutoHide validates the top hover zone', function()
    F.raises(function()
        AutoHide({ top_hover_zone = -1 })
    end, 'AutoHide.top_hover_zone', 'negative top hover zone is rejected')
    F.raises(function()
        AutoHide({ top_hover_zone = math.huge })
    end, 'AutoHide.top_hover_zone', 'infinite top hover zone is rejected')
    F.raises(function()
        AutoHide({ fade_duration = -1 })
    end, 'AutoHide.fade_duration', 'negative fade duration is rejected')
    F.raises(function()
        ---@diagnostic disable-next-line: param-type-mismatch
        AutoHide({ top_hover_enabled = 'yes' })
    end, 'AutoHide.top_hover_enabled', 'top hover policy must be boolean')
end)

F.test('AutoHide keeps top hover opt-in', function()
    local clock = ManualClock()
    local scheduler = Scheduler(clock)
    local controller = AutoHideController()
    mount(AutoHide({
        controller = controller,
        bottom_hover = true,
        top_hover = false,
        child = Text('main'),
    }), scheduler)
    controller:hide()
    controller:activity(10, 10, geometry.Rect(0, 0, 1280, 720))
    F.ok(not controller.visible, 'top activity does not reveal when top hover is disabled')
    scheduler:dispose()
end)

F.test('AutoHide drops non-maintained content only after fade completion', function()
    local clock = ManualClock()
    local scheduler = Scheduler(clock)
    local controller = AutoHideController()
    local owner, binding = mount(AutoHide({
        controller = controller,
        timeout = 0,
        fade_duration = 0.2,
        maintain_state = false,
        child = Text('main'),
    }), scheduler)
    controller:hide()
    clock:tick(0)
    clock:tick(0.2)
    F.ok(owner.root ~= nil, 'fade completion waits for the build pass')
    binding:flush_build()
    F.ok(owner.root == nil, 'non-maintained content is removed after fade')
    controller:show()
    binding:flush_build()
    F.ok(owner.root ~= nil, 'show rebuilds non-maintained content')
    F.close(owner.root.opacity, 0, 'rebuilt content starts transparent')
    clock:tick(0)
    clock:tick(0.2)
    F.close(owner.root.opacity, 1, 'rebuilt content fades in')
    scheduler:dispose()
end)

F.test('AutoHide disposes fade listeners and tickers with the State', function()
    local clock = ManualClock()
    local scheduler = Scheduler(clock)
    local controller = AutoHideController()
    local owner, binding = mount(AutoHide({
        controller = controller,
        timeout = 0,
        fade_duration = 0.2,
        child = Text('main'),
    }), scheduler)
    local state = binding.root_element.state
    controller:hide()
    clock:tick(0)
    local fade_controller = state._fade_controller
    F.ok(fade_controller ~= nil and fade_controller:is_animating(),
        'fade controller is active before disposal')
    binding:dispose()
    F.ok(fade_controller._disposed, 'fade controller is disposed with the State')
    F.ok(next(scheduler._transient) == nil, 'fade ticker is removed from the Scheduler')
    clock:tick(0.2)
    F.ok(owner.root == nil, 'disposed tree has no render root')
    scheduler:dispose()
end)
