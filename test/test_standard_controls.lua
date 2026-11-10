-- Standalone controls extracted from the player, without a player/host scope.
---@namespace test.standardcontrols
---@diagnostic disable: undefined-field, inject-field, need-check-nil

local F = require 'framework'
local std = require 'elxlibs.std'
local geometry = require 'foundation.geometry'
local text_layout = require 'text.text_layout'
local TextStyle = require('text.text_style').TextStyle
local Color = require('foundation.color').Color
local Constraints = require('layout.constraints').Constraints
local RenderOwner = require('render.render_owner').RenderOwner
local WidgetBinding = require('widget.binding').WidgetBinding
local RecordCanvas = require('backends.record').RecordCanvas
local basic = require 'widget.widgets.basic'
local Tooltip = require('widget.widgets.tooltip').Tooltip
local LinearProgressIndicator = require('widget.widgets.progress_indicator').LinearProgressIndicator
local Slider = require('widget.widgets.slider').Slider
local HoverText = require('widget.widgets.hover_text').HoverText
local Offset = geometry.Offset
local FrameClock = require('scheduler.frame_clock').FrameClock

---@class ControlClock : FrameClock
---@field time number
---@overload fun(): self
local ControlClock = std.class.new('ControlClock', FrameClock)
function ControlClock:__init()
    FrameClock.__init(self)
    self.time = 0
end
function ControlClock:now()
    return self.time
end
function ControlClock:request_frame() end
function ControlClock:tick(time)
    self.time = time
    self:_emit(time)
end

---@class ControlTextLayout : TextLayout
---@field calls integer
---@overload fun(): self
local ControlTextLayout = std.class.new('ControlTextLayout', text_layout.TextLayout)
function ControlTextLayout:__init()
    self.calls = 0
end
function ControlTextLayout:line_width(line, style)
    self.calls = self.calls + 1
    return #line * style.font_size * 0.5
end

local function mount(widget, constraints)
    local owner = RenderOwner()
    local tree = WidgetBinding.ensure_initialized():attach(widget, owner)
    owner:set_viewport(constraints or Constraints.tight(200, 20))
    owner:layout()
    owner:paint(RecordCanvas())
    return owner, tree
end

local function label_draw(owner, label)
    local canvas = RecordCanvas()
    owner:paint(canvas)
    for _, op in ipairs(canvas.ops) do
        if op.name == 'draw_text' and op[1].text == label then
            return op, canvas
        end
    end
    return nil, canvas
end

F.section('standard controls')

F.test('standard aggregates and player adapters share the owning classes', function()
    local widgets = require 'widget'
    for name, class in pairs({ Tooltip = Tooltip, LinearProgressIndicator = LinearProgressIndicator, Slider = Slider,
        HoverText = HoverText }) do
        F.eq(basic[name], class, 'basic identity: ' .. name)
        F.eq(widgets[name], class, 'widget identity: ' .. name)
    end
    local Timeline = require('widget.player.timeline').Timeline
    F.eq(widgets.Timeline, Timeline, 'timeline aggregate identity')
    F.ok(std.isinstance(Timeline(), Slider), 'timeline specializes the slider widget')
    F.eq(widgets.ProgressBar, nil, 'mixed progress/seek API removed')
    F.ok(not std.isinstance(Slider(), Timeline), 'standard slider is independent of timeline')
    F.eq(require('widget.player.text_controls').PlayerHoverText, HoverText, 'text alias')
    local options = { text = 'tip' }
    local player_tip = require('widget.player.tooltip').PlayerTooltip(options)
    F.ok(std.isinstance(player_tip, Tooltip), 'player inherits standard tooltip lifecycle')
    F.eq(options.style, nil, 'player default does not modify caller options')
    F.eq(player_tip.style.font_size, 18, 'player visual default is preserved')
    F.eq(Tooltip(options).style.font_size, 16, 'standard visual default is independent')
end)

F.test('tooltip centers on child size, reuses text layout and passes clicks through', function()
    local measurer = ControlTextLayout()
    text_layout.set_default(measurer)
    local clicks, leaves, points = 0, 0, 0
    local owner, tree = mount(Tooltip({
        text = 'hint',
        child = basic.GestureDetector(basic.CustomPaint({ preferred_size = geometry.Size(80, 20) }), {
            on_tap = function() clicks = clicks + 1 end,
        }),
        on_hover_point = function() points = points + 1 end,
        on_hover_leave = function() leaves = leaves + 1 end,
    }), Constraints.loose(200, 100))
    F.eq(owner.root.size, geometry.Size(80, 20), 'tooltip preserves intrinsic child size')
    local snapshot = owner:region_snapshot()
    owner:dispatch_pointer('move', Offset(20, 10))
    local draw = label_draw(owner, 'hint')
    F.eq(draw[2].x, 40, 'default anchor centers on actual child width')
    local calls = measurer.calls
    owner:dispatch_pointer('move', Offset(40, 10))
    label_draw(owner, 'hint')
    local next_calls = measurer.calls
    F.eq(next_calls, calls, 'pointer motion reuses the measured paragraph')
    F.eq(owner:region_snapshot(), snapshot, 'hover reuses the input snapshot')
    F.ok(not owner:needs_layout() and not tree.build_owner:has_dirty(), 'hover only invalidates paint')
    owner:dispatch_pointer('down', Offset(40, 10), 'left')
    owner:dispatch_pointer('up', Offset(40, 10), 'left')
    F.eq(clicks, 1, 'child retains click handling')
    F.ok(points >= 2, 'preview hook works without pointer-following text')
    tree:dispose()
    tree:dispose()
    F.eq(leaves, 1, 'hover resource released once on disposal')
end)

F.test('tooltip fits bounded labels, flips below a top edge and preserves disabled feedback', function()
    text_layout.set_default(ControlTextLayout())
    local owner, tree = mount(Tooltip({
        text = 'active', disabled_text = 'disabled label', enabled = false,
        follow_pointer = true, bounds_width = 80, bounds_height = 100,
        anchor_width = 80, anchor_height = 20, margin = 10,
        style = TextStyle({ font_size = 16, wrap = false }),
    }), Constraints.tight(80, 20))
    owner:dispatch_pointer('move', Offset(79, 10))
    local draw, canvas = label_draw(owner, 'disabled label')
    F.eq(draw[2].x, 40, 'wide label stays centered inside margins')
    F.eq(draw[2].y, 20, 'top edge flips label below the child')
    F.eq(draw[3].anchor, 'top_center', 'flipped anchor')
    F.eq(canvas:count('clip_rect'), 1, 'overwide label is clipped to available width')
    F.ok(not owner:dispatch_pointer('down', Offset(20, 10), 'left'), 'tooltip claims no click')
    owner:dispatch_pointer('move', Offset(90, 10))
    F.eq(label_draw(owner, 'disabled label'), nil, 'leave removes label')
    tree:dispose()
    F.raises(function() Tooltip({ bounds_width = math.huge }) end, 'finite', 'finite bounds')
    F.raises(function() Tooltip({ margin = -1 }) end, 'non-negative', 'non-negative margin')
end)

F.test('slider separates start, change and end callbacks and quantizes numeric selection', function()
    local changes = {}
    local options = { min = 10, max = 110, value = 35, divisions = 4, track_inset = 0,
        on_changed = function(value) changes[#changes + 1] = { value, 'change' } end,
        on_change_start = function(value) changes[#changes + 1] = { value, 'start' } end,
        on_change_end = function(value) changes[#changes + 1] = { value, 'end' } end }
    local slider = Slider(options)
    F.eq(options.thumb_radius, nil, 'slider defaults do not mutate options')
    local owner, tree = mount(slider)
    owner:dispatch_pointer('down', Offset(110, 10), 'left')
    owner:dispatch_pointer('move', Offset(111, 10))
    owner:dispatch_pointer('move', Offset(155, 10))
    owner:dispatch_pointer('up', Offset(500, 10), 'left')
    F.eq(changes[1][1], 35, 'start reports previous controlled value')
    F.eq(changes[1][2], 'start', 'start precedes change')
    F.eq(changes[2][1], 60, 'tap maps to the numeric range')
    F.eq(changes[3][1], 85, 'drag maps to the next division')
    F.eq(changes[4][1], 85, 'outside release retains last captured value')
    F.eq(changes[4][2], 'end', 'end has its own callback')
    F.eq(#changes, 4, 'duplicate division emits no change')
    F.eq(slider.value, 35, 'displayed value remains controlled')
    owner:dispatch_pointer('down', Offset(199, 10), 'left')
    owner:dispatch_pointer('cancel', nil)
    F.eq(changes[#changes][1], 110, 'cancel reports final drag value')
    F.eq(changes[#changes][2], 'end', 'cancel completes interaction like Flutter')
    tree:dispose()
end)

F.test('slider updates reuse render identity and disabled/empty ranges have no input', function()
    local callback = function() end
    local owner, tree = mount(Slider({ value = 0.1, on_changed = callback }))
    local render = owner.root
    tree:set_root_widget(Slider({ value = 0.7, on_changed = callback }))
    tree:flush_build()
    F.eq(owner.root, render, 'persistent render target')
    F.ok(owner:needs_paint() and not owner:needs_layout(), 'controlled value is paint-only')
    F.close(render.value, 0.7, 'new controlled value painted')
    tree:set_root_widget(Slider({ value = 0.7 }))
    tree:flush_build()
    F.eq(#owner:pointer_regions(), 0, 'missing on_changed disables slider')
    F.ok(not owner:dispatch_pointer('down', Offset(20, 10), 'left'), 'disabled slider rejects drag')
    tree:set_root_widget(Slider({ value = 1, min = 1, max = 1, on_changed = callback }))
    tree:flush_build()
    F.eq(#owner:pointer_regions(), 0, 'equal bounds disable slider')
    tree:dispose()
    for _, invalid in ipairs({ { min = 2, max = 1 }, { value = 2 }, { value = 0 / 0 },
        { max = math.huge }, { divisions = 0 }, { divisions = 1.5 },
        { secondary_track_value = 2 }, { min = -1e308, max = 1e308 } }) do
        F.raises(function() Slider(invalid) end, 'Slider.', 'invalid numeric boundary rejected')
    end
end)

F.test('slider geometry uses track padding and paints thumb, secondary track and disabled colors', function()
    local owner, tree = mount(Slider({ value = 0.25, secondary_track_value = 0.6,
        on_changed = function() end }), Constraints.tight(200, 48))
    F.eq(owner.root:track_rect(), geometry.Rect(20, 22, 180, 26), 'padded track geometry')
    local canvas = RecordCanvas()
    owner.root:mark_needs_paint()
    owner:paint(canvas)
    F.eq(canvas:count('draw_rrect'), 4, 'track, secondary track, active track and thumb')
    owner:dispatch_pointer('move', Offset(60, 24))
    canvas = RecordCanvas()
    owner:paint(canvas)
    F.eq(canvas:count('draw_rrect'), 5, 'hover overlay is separate from thumb')
    tree:dispose()
    local disabled_owner, disabled_tree = mount(Slider({ value = 0.25 }), Constraints.tight(200, 48))
    local disabled_canvas = RecordCanvas()
    disabled_owner.root:mark_needs_paint()
    disabled_owner:paint(disabled_canvas)
    F.eq(disabled_canvas.ops[1][3].color, disabled_owner.root.disabled_inactive_color,
        'disabled track has explicit styling')
    disabled_tree:dispose()
    local loose_owner, loose_tree = mount(Slider(), Constraints())
    F.eq(loose_owner.root.size, geometry.Size(184, 48), 'unbounded slider uses finite preferred size')
    loose_tree:dispose()
end)

F.test('disabling or removing an active slider completes its interaction exactly once', function()
    local endings = {}
    local owner, tree = mount(Slider({ value = 0.25, track_inset = 0,
        on_changed = function() end,
        on_change_end = function(value) endings[#endings + 1] = value end }))
    owner:dispatch_pointer('down', Offset(100, 10), 'left')
    tree:set_root_widget(Slider({ value = 0.25 }))
    tree:flush_build()
    F.eq(#endings, 1, 'callback removal completes old interaction')
    F.eq(endings[1], 0.5, 'completion retains drag value')
    tree:dispose()
    F.eq(#endings, 1, 'dispose does not duplicate completion')
end)

F.test('controlled slider suppresses redundant values while retaining each distinct drag proposal', function()
    local changes = {}
    local owner, tree = mount(Slider({ value = 0, track_inset = 0,
        on_changed = function(value) changes[#changes + 1] = value end }))
    owner:dispatch_pointer('down', Offset(100, 10), 'left')
    owner:dispatch_pointer('move', Offset(0, 10))
    owner:dispatch_pointer('move', Offset(100, 10))
    F.eq(#changes, 2, 'returning to controlled value resets duplicate suppression')
    F.eq(changes[2], 0.5, 'distinct proposal can repeat after a different value')
    owner:dispatch_pointer('cancel')
    tree:dispose()
end)

F.test('linear progress is read-only, clamps finite values and has no thumb or seek API', function()
    local owner, tree = mount(LinearProgressIndicator({ value = 0.25 }), Constraints.tight(200, 4))
    local canvas = RecordCanvas()
    owner.root:mark_needs_paint()
    owner:paint(canvas)
    F.eq(canvas:count('draw_rrect'), 2, 'only track and completed segment')
    F.eq(canvas.ops[2][1]:width(), 50, 'determinate fill width')
    F.eq(#owner:pointer_regions(), 0, 'progress never claims pointer input')
    F.eq(owner.root.on_seek, nil, 'progress has no seek callback')
    local identity = owner.root
    tree:set_root_widget(LinearProgressIndicator({ value = 2 }))
    tree:flush_build()
    F.eq(owner.root, identity, 'progress render identity preserved')
    F.eq(owner.root.value, 1, 'progress clamps above one')
    F.ok(owner:needs_paint() and not owner:needs_layout(), 'progress value is paint-only')
    tree:set_root_widget(LinearProgressIndicator({ value = -1 }))
    tree:flush_build()
    F.eq(owner.root.value, 0, 'progress clamps below zero')
    tree:dispose()
    F.raises(function() LinearProgressIndicator({ value = 0 / 0 }) end, 'finite', 'invalid value rejected')
    F.raises(function() LinearProgressIndicator({ min_height = 0 }) end, 'invalid', 'invalid height rejected')
end)

F.test('indeterminate progress uses owned ticker without rebuilds and releases it on mode/dispose', function()
    local Scheduler = require('scheduler.scheduler').Scheduler
    local clock = ControlClock()
    local scheduler = Scheduler(clock)
    local owner = RenderOwner()
    local tree = WidgetBinding.ensure_initialized():attach(LinearProgressIndicator(), owner, scheduler)
    owner:set_viewport(Constraints.tight(200, 4))
    owner:layout()
    owner:paint(RecordCanvas())
    local state = tree.root_element.state
    F.ok(state._ticker:is_active(), 'indeterminate ticker starts')
    clock:tick(0)
    clock:tick(0.5)
    F.ok(owner.root.phase > 0, 'frame clock advances activity')
    F.ok(owner:needs_paint() and not owner:needs_layout() and not tree.build_owner:has_dirty(),
        'animation updates paint without rebuild/layout')
    tree:set_root_widget(LinearProgressIndicator({ value = 0.3 }))
    tree:flush_build()
    F.ok(not state._ticker:is_active(), 'determinate mode stops ticker')
    tree:set_root_widget(LinearProgressIndicator())
    tree:flush_build()
    F.ok(state._ticker:is_active(), 'returning to indeterminate restarts ticker')
    tree:dispose()
    F.ok(not state._ticker:is_active(), 'dispose releases ticker')
end)

F.test('standalone HoverText retains paint-only hover and click behavior', function()
    text_layout.set_default(ControlTextLayout())
    local clicks = 0
    local owner, tree = mount(HoverText({ text = 'action', on_tap = function() clicks = clicks + 1 end,
        hover_color = Color.rgba255(0, 255, 0), hover_shadow_radius = 2 }))
    owner:dispatch_pointer('move', Offset(100, 10))
    F.ok(not owner:needs_layout() and not tree.build_owner:has_dirty(), 'text hover is paint-only')
    owner:dispatch_pointer('down', Offset(100, 10), 'left')
    owner:dispatch_pointer('up', Offset(100, 10), 'left')
    F.eq(clicks, 1, 'standard text click')
    tree:dispose()
end)
