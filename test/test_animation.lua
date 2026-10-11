-- Phase 1: affine values, paint-only offsets and frame-clock animations.

---@diagnostic disable: undefined-field, inject-field, need-check-nil,
--- generic-constraint-mismatch, preferred-local-alias, unused, call-non-callable

local F = require 'framework'
local std = require 'elxlibs.std'

local geometry = require 'foundation.geometry'
local transform_mod = require 'foundation.transform'
local constraints_mod = require 'layout.constraints'
local render_owner_mod = require 'render.render_owner'
local custom_paint_mod = require 'render.custom_paint'
local offset_box_mod = require 'render.offset_box'
local record_mod = require 'backends.record'
local ass_canvas_mod = require 'backends.ass_canvas'
local scheduler_mod = require 'scheduler.scheduler'
local frame_clock_mod = require 'scheduler.frame_clock'
local controller_mod = require 'animation.controller'
local curve_mod = require 'animation.curve'
local tween_mod = require 'animation.tween'
local binding_mod = require 'widget.binding'
local widget_mod = require 'widget.widget'
local state_mod = require 'widget.state'
local layout_widgets = require 'widget.widgets.layout'

local Offset = geometry.Offset
local Size = geometry.Size
local Rect = geometry.Rect
local Color = require('foundation.color').Color
local Paint = require('painting.paint').Paint
local Matrix2D = transform_mod.Matrix2D
local Constraints = constraints_mod.Constraints
local RenderOwner = render_owner_mod.RenderOwner
local RenderCustomPaint = custom_paint_mod.RenderCustomPaint
local RenderOffsetBox = offset_box_mod.RenderOffsetBox
local RecordCanvas = record_mod.RecordCanvas
local AssCanvas = ass_canvas_mod.AssCanvas
local FrameClock = frame_clock_mod.FrameClock
local Scheduler = scheduler_mod.Scheduler
local AnimationController = controller_mod.AnimationController
local Tween = tween_mod.Tween
local OffsetBox = layout_widgets.OffsetBox
local WidgetBinding = binding_mod.WidgetBinding
local StatefulWidget = widget_mod.StatefulWidget
local State = state_mod.State

---@class test.AnimationClock : FrameClock
---@overload fun(time: number?): self
local ManualClock = std.class.new('test.AnimationClock', { FrameClock })

function ManualClock:__init(time)
    self.time = time or 0
    self.pending = false
    self.requests = 0
end

function ManualClock:now()
    return self.time
end

function ManualClock:request_frame()
    self.pending = true
    self.requests = self.requests + 1
end

---@param dt number
function ManualClock:tick(dt)
    self.time = self.time + dt
    if self.pending then
        self.pending = false
        self:_emit()
    end
end

---@param w number
---@param h number
---@return RenderCustomPaint
local function box(w, h)
    return RenderCustomPaint(nil, { preferred_size = Size(w, h) })
end

---@param root RenderObject
---@return RenderOwner
local function layout_root(root)
    local owner = RenderOwner(root)
    owner:set_viewport(Constraints.loose(100, 100))
    owner:layout()
    return owner
end

F.section('transform: Matrix2D')

F.test('identity, translation and scale transform logical points', function()
    local identity = Matrix2D.identity()
    F.ok(identity:is_identity(), 'identity reports itself')
    F.ok(identity:transform_point(Offset(3, 4)) == Offset(3, 4), 'identity point')
    F.ok(Matrix2D.translation(10, 20):transform_point(Offset(3, 4)) == Offset(13, 24),
        'translation point')
    F.ok(Matrix2D.scale(2, 3):transform_point(Offset(3, 4)) == Offset(6, 12),
        'axis scale point')
end)

F.test('multiply follows column-vector order and transforms rectangles', function()
    local translate_then_scale = Matrix2D.translation(10, 20):multiply(Matrix2D.scale(2, 3))
    F.ok(translate_then_scale:transform_point(Offset(3, 4)) == Offset(16, 32),
        'scale first, translation second')
    local bounds = translate_then_scale:transform_rect(Rect(0, 0, 5, 7))
    F.ok(bounds == Rect(10, 20, 20, 41), 'transformed AABB')
    local reverse = Matrix2D.scale(2):multiply(Matrix2D.translation(10, 20))
    F.ok(reverse:transform_point(Offset(3, 4)) == Offset(26, 48),
        'translation first, scale second')
end)

F.test('inverse round-trips points and singular transforms are explicit', function()
    local matrix = Matrix2D.translation(10, -3):multiply(Matrix2D.scale(2, 4))
    local inverse = matrix:inverse()
    F.ok(inverse ~= nil, 'regular transform has an inverse')
    local point = Offset(5, 7)
    F.ok(inverse:transform_point(matrix:transform_point(point)) == point, 'inverse round trip')
    F.eq(Matrix2D.scale(0, 2):inverse(), nil, 'singular transform has no inverse')
end)

F.section('render: OffsetBox')

F.test('offset preserves layout size and translates ASS drawing output', function()
    local child = RenderCustomPaint(function(canvas, offset, size)
        canvas:draw_rect(Rect.from_offset_size(offset, size), Paint())
    end, { preferred_size = Size(20, 10) })
    local root = RenderOffsetBox(Offset(15, 5), child)
    local owner = layout_root(root)
    F.ok(root.size == Size(20, 10), 'offset does not affect layout size')

    local record = RecordCanvas()
    owner:paint(record)
    F.eq(record.ops[1].name, 'save', 'offset saves canvas state')
    F.eq(record.ops[2].name, 'translate', 'offset translates canvas')
    F.eq(record.ops[2][1], 15, 'x translation')
    F.eq(record.ops[2][2], 5, 'y translation')
    F.eq(record.ops[4].name, 'restore', 'offset restores canvas state')

    local canvas = AssCanvas()
    root:paint(canvas, Offset.zero())
    F.contains(canvas:text(), 'm 120 40', 'ASS geometry receives the offset')
end)

F.test('offset reverses child coordinates for hit testing and stays parent-clipped', function()
    local child = box(20, 10)
    local root = RenderOffsetBox(Offset(15, 5), child)
    layout_root(root)
    local inside = root:pointer_path(Offset(16, 6))
    F.eq(#inside, 2, 'translated child is hit')
    F.ok(inside[1].node == child, 'child is deepest hit')
    F.ok(inside[1].point == Offset(1, 1), 'child receives inverse-translated point')
    local outside = root:pointer_path(Offset(1, 1))
    F.eq(#outside, 1, 'untranslated child point misses')
    F.ok(outside[1].node == root, 'root remains the clipped hit target')
end)

F.test('offset animation marks paint without relayout and detaches cleanly', function()
    local clock = ManualClock()
    local scheduler = Scheduler(clock)
    local child = box(20, 10)
    local root = RenderOffsetBox(Offset.zero(), child)
    local owner = layout_root(root)
    owner.on_dirty = function() end
    local controller = AnimationController(scheduler, { duration = 1 })
    root:bind_offset_animation(controller, Tween(Offset.zero(), Offset(10, 0)))
    controller:forward()
    clock:tick(0)
    owner._needs_layout = false
    owner._needs_paint = false
    clock:tick(0.5)
    F.ok(root.offset == Offset(5, 0), 'offset follows controller and tween')
    F.ok(not owner:needs_layout(), 'paint-only offset does not request layout')
    F.ok(owner:needs_paint(), 'paint-only offset requests paint')
    root:_set_owner(nil)
    F.eq(root._offset_animation, nil, 'detaching removes animation listener')
    controller:dispose()
end)

F.section('animation: curves and tweens')

F.test('curves stay normalized and preserve endpoints', function()
    for _, curve in ipairs({ curve_mod.linear, curve_mod.ease_in, curve_mod.ease_out, curve_mod.ease_in_out }) do
        F.close(curve(0), 0, 'curve start')
        F.close(curve(1), 1, 'curve end')
    end
    F.close(curve_mod.ease_in(0.5), 0.25, 'ease in')
    F.close(curve_mod.ease_out(0.5), 0.75, 'ease out')
end)

F.test('tween interpolates supported values and accepts a custom lerp', function()
    F.close(Tween(0, 10):value_at(0.25), 2.5, 'number tween')
    F.ok(Tween(Offset(0, 2), Offset(10, 6)):value_at(0.5) == Offset(5, 4), 'offset tween')
    F.ok(Tween(Size(0, 2), Size(10, 6)):value_at(0.5) == Size(5, 4), 'size tween')
    F.ok(Tween(Color(0, 0, 0), Color(1, 1, 1)):value_at(0.5) == Color(0.5, 0.5, 0.5),
        'color tween')
    local custom = Tween('a', 'b', function(begin_value, end_value, t)
        return t < 0.5 and begin_value or end_value
    end)
    F.eq(custom:value_at(0.25), 'a', 'custom tween before midpoint')
    F.eq(custom:value_at(0.75), 'b', 'custom tween after midpoint')
end)

F.section('animation: controller')

F.test('controller samples on frames, completes, and stops requesting frames', function()
    local clock = ManualClock(10)
    local scheduler = Scheduler(clock)
    local values = {}
    local controller = AnimationController(scheduler, { duration = 1 })
    controller:add_listener(function(animation)
        values[#values + 1] = animation.value
    end)
    controller:forward()
    F.ok(controller:is_animating(), 'forward starts ticker')
    F.eq(clock.requests, 1, 'forward requests a frame')
    clock:tick(0)
    F.close(controller.value, 0, 'first sample is zero elapsed')
    clock:tick(0.25)
    F.close(controller.value, 0.25, 'quarter sample')
    clock:tick(0.75)
    F.close(controller.value, 1, 'final sample')
    F.eq(controller.status, 'completed', 'completed status')
    F.ok(not controller:is_animating(), 'completed stops ticker')
    F.ok(#values >= 3, 'listeners receive samples')
    F.eq(clock.pending, false, 'clock goes idle after completion')
end)

F.test('ticker time is reset between animations after an idle gap', function()
    local clock = ManualClock(100)
    local scheduler = Scheduler(clock)
    local controller = AnimationController(scheduler, { duration = 1 })
    controller:forward()
    clock:tick(0)
    clock:tick(0.2)
    controller:stop()
    clock.time = clock.time + 50
    controller:forward()
    clock:tick(0)
    F.close(controller.value, 0.2, 'new animation starts without stale scheduler delta')
end)

F.test('reverse, reset, repeat, listener removal and disposal work', function()
    local clock = ManualClock()
    local scheduler = Scheduler(clock)
    local controller = AnimationController(scheduler, { duration = 1, value = 1 })
    local calls = 0
    local listener = function() calls = calls + 1 end
    controller:add_listener(listener)
    controller:reverse()
    clock:tick(0)
    clock:tick(1)
    F.eq(controller.status, 'dismissed', 'reverse reaches dismissed')
    controller:reset()
    F.eq(controller.value, 0, 'reset value')
    controller:remove_listener(listener)
    local previous = calls
    controller:repeat_animation({ count = 1 })
    clock:tick(0)
    clock:tick(1)
    F.eq(controller.value, 1, 'repeat one cycle')
    F.eq(controller.status, 'completed', 'repeat completes')
    F.eq(calls, previous, 'removed listener stays removed')
    controller:dispose()
    F.ok(not controller:is_animating(), 'dispose stops ticker')
    controller:dispose()
end)

F.section('animation: State lifecycle')

F.test('State-owned controllers receive a scheduler and dispose on unmount', function()
    local clock = ManualClock()
    local scheduler = Scheduler(clock)
    local disposed = 0
    local AnimationState = std.class.new('test.AnimationState', { State })
    function AnimationState:init_state()
        self.controller = self:create_animation_controller({ duration = 1 })
    end
    function AnimationState:dispose()
        disposed = disposed + 1
    end
    function AnimationState:build()
        return OffsetBox({ offset = Offset.zero(), child = nil })
    end
    local AnimationWidget = std.class.new('test.AnimationWidget', { StatefulWidget })
    function AnimationWidget:create_state()
        return AnimationState()
    end
    local owner = RenderOwner()
    local binding = WidgetBinding(AnimationWidget(), owner, nil, scheduler)
    owner:set_viewport(Constraints.loose(100, 100))
    owner:layout()
    local state = binding.root_element.state
    state.controller:forward()
    F.ok(scheduler:is_frame_scheduled(), 'state controller schedules frames')
    binding.root_element:unmount()
    F.eq(disposed, 1, 'user dispose is called')
    F.ok(not state.controller:is_animating(), 'owned controller is stopped after unmount')
end)

F.section('animation: module and widget identity')

F.test('OffsetBox and animation aggregate exports are stable', function()
    local animation = require 'animation'
    F.eq(animation.AnimationController, AnimationController, 'controller aggregate')
    F.eq(animation.Tween, Tween, 'tween aggregate')
    F.eq(layout_widgets.OffsetBox, OffsetBox, 'offset widget aggregate')
    F.eq(require('widget').OffsetBox, OffsetBox, 'widget aggregate')
end)
