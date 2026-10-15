-- Pointer routing: path resolution, gesture dispatch and hover tracking.

-- See the note in test_widget.lua: the `std.class` / optional-ownership
-- diagnostics are disabled across the suite.
---@diagnostic disable: undefined-field, inject-field, need-check-nil, generic-constraint-mismatch, preferred-local-alias, unused

local F = require('framework')

local geometry = require('foundation.geometry')
local constraints_mod = require('layout.constraints')
local render_owner = require('render.render_owner')
local pointer_event = require('foundation.pointer_event')
local custom_paint = require('render.custom_paint')
local fitted_box = require('render.fitted_box')
local gesture_mod = require('render.gesture')
local layout_scale_box = require('render.layout_scale_box')
local offset_box = require('render.offset_box')
local padding_mod = require('render.padding')
local transform_box = require('render.transform_box')

local Offset, Size, Rect, EdgeInsets = geometry.Offset, geometry.Size, geometry.Rect, geometry.EdgeInsets
local Constraints = constraints_mod.Constraints
local RenderOwner = render_owner.RenderOwner
local PointerEvent = pointer_event.PointerEvent
local RenderCustomPaint = custom_paint.RenderCustomPaint
local RenderFittedBox = fitted_box.RenderFittedBox
local RenderGesture = gesture_mod.RenderGesture
local RenderLayoutScaleBox = layout_scale_box.RenderLayoutScaleBox
local RenderOffsetBox = offset_box.RenderOffsetBox
local RenderPadding = padding_mod.RenderPadding
local RenderTransformBox = transform_box.RenderTransformBox

---@param w number
---@param h number
local function box(w, h)
    return RenderCustomPaint(nil, { preferred_size = Size(w, h) })
end

---@param node RenderObject
---@param viewport Constraints
---@return RenderOwner
local function laid_out_with(node, viewport)
    local owner = RenderOwner(node)
    owner:set_viewport(viewport)
    owner:layout()
    return owner
end

---@param node RenderObject
---@return RenderOwner
local function laid_out(node)
    return laid_out_with(node, Constraints.loose(200, 200))
end

F.section('input: pointer path')

F.test('lists nodes deepest-first with local points', function()
    local leaf = box(10, 10)
    local root = RenderPadding(EdgeInsets.all(5), leaf)
    root:layout(Constraints.unbounded())
    local path = root:pointer_path(Offset(7, 7))
    F.eq(#path, 2, 'leaf + padding')
    F.ok(path[1].node == leaf, 'deepest first')
    F.ok(path[1].point == Offset(2, 2), 'point converted to leaf space')
    F.ok(path[2].node == root, 'ancestor last')
end)

F.test('is empty when the point misses the tree', function()
    local node = box(10, 10)
    node:layout(Constraints.unbounded())
    F.eq(#node:pointer_path(Offset(100, 100)), 0, 'no hit')
end)

F.test('collects interactive regions in root coordinates', function()
    local owner = laid_out(RenderPadding(EdgeInsets.all(10), RenderGesture(box(40, 20), {
        expand = 5,
        on_tap = function() end,
    })))
    local regions = owner:pointer_regions()
    F.eq(#regions, 1, 'only the gesture is interactive')
    F.ok(regions[1].rect == Rect(5, 5, 55, 35), 'padding and expanded hit area compose')
    F.ok(regions[1].down, 'tap region handles button input')
    F.ok(not regions[1].wheel, 'tap region does not claim wheel input')
end)

F.test('clips transformed child regions to the ancestor hit bounds', function()
    local owner = laid_out(RenderOffsetBox(Offset(20, 0), RenderGesture(box(10, 10), {
        on_tap = function() end,
    })))
    F.eq(#owner:pointer_regions(), 0, 'an offset child outside its parent is not interactive')
end)

F.test('maps and clips paint-only transform regions', function()
    local root = RenderTransformBox(RenderGesture(box(10, 5), {
        on_tap = function() end,
    }), { scale = Size(2, 2), alignment = Offset(0, 0) })
    local owner = laid_out(root)
    local regions = owner:pointer_regions()
    F.eq(#regions, 1, 'the gesture remains the only interactive region')
    F.ok(regions[1].rect == Rect(0, 0, 10, 5),
        'the transformed region follows hit-test clipping')
end)

F.test('omits empty own interactive regions', function()
    local owner = laid_out(RenderGesture(box(0, 0), {
        on_tap = function() end,
    }))
    F.eq(#owner:pointer_regions(), 0, 'zero-sized own region is omitted')
end)

F.test('composes nested mappings and clips each ancestor', function()
    local gesture = RenderGesture(box(20, 10), {
        on_tap = function() end,
    })
    local transformed = RenderTransformBox(gesture, {
        scale = Size(1.5, 1),
        alignment = Offset(0, 0),
    })
    local root = RenderPadding(EdgeInsets.all(2), RenderOffsetBox(Offset(5, 7), transformed))
    local regions = laid_out(root):pointer_regions()
    F.eq(#regions, 1, 'nested tree has one interactive region')
    F.ok(regions[1].rect == Rect(7, 9, 22, 12),
        'offset, scale, padding, and both clips compose')
end)

F.test('retains the visible part of a partially clipped region', function()
    local root = RenderOffsetBox(Offset(8, 3), RenderGesture(box(10, 10), {
        on_tap = function() end,
    }))
    local regions = laid_out(root):pointer_regions()
    F.eq(#regions, 1, 'partial region remains interactive')
    F.ok(regions[1].rect == Rect(8, 3, 10, 10), 'region is clipped to the parent')
end)

F.test('maps FittedBox letterboxing and crop to hit regions', function()
    local contain = RenderFittedBox(RenderGesture(box(200, 50), {
        on_tap = function() end,
    }), { fit = 'contain' })
    local contain_regions = laid_out_with(contain, Constraints.tight(100, 100)):pointer_regions()
    F.eq(#contain_regions, 1, 'letterboxed child remains interactive')
    F.ok(contain_regions[1].rect == Rect(0, 37.5, 100, 62.5),
        'contain keeps the letterbox outside the region')

    local cover_child = RenderPadding(EdgeInsets.only({ left = 100, right = 80 }),
        RenderGesture(box(20, 50), { on_tap = function() end }))
    local cover = RenderFittedBox(cover_child, { fit = 'cover' })
    local cover_regions = laid_out_with(cover, Constraints.tight(100, 100)):pointer_regions()
    F.eq(#cover_regions, 1, 'cropped child remains interactive')
    F.ok(cover_regions[1].rect == Rect(50, 0, 90, 100),
        'cover maps the visible source slice into the destination')
end)

F.test('maps LayoutScaleBox through its layout scale', function()
    local root = RenderLayoutScaleBox(RenderGesture(box(20, 10), {
        on_tap = function() end,
    }), { scale = Size(2, 3), alignment = Offset(0, 0) })
    local owner = laid_out_with(root, Constraints.tight(40, 30))
    local regions = owner:pointer_regions()
    F.eq(root.size, Size(40, 30), 'layout scale reports its scaled size')
    F.eq(#regions, 1, 'scaled child remains interactive')
    F.ok(regions[1].rect == Rect(0, 0, 40, 30), 'layout scale maps the child region')
end)

F.test('refreshes regions after a paint-only transform update', function()
    local root = RenderTransformBox(RenderGesture(box(20, 20), {
        on_tap = function() end,
    }), { scale = Size(0.5, 0.5), alignment = Offset(0.5, 0.5) })
    local owner = laid_out_with(root, Constraints.tight(20, 20))
    local before = owner:pointer_regions()
    F.ok(before[1].rect == Rect(5, 5, 15, 15), 'initial paint transform is mapped')
    F.ok(not owner:needs_layout(), 'paint-only transform does not need layout')

    root:set_scale(Size(1, 1))
    F.ok(not owner:needs_layout(), 'scale update remains paint-only')
    F.ok(owner:needs_paint(), 'scale update marks paint dirty')
    local after = owner:pointer_regions()
    F.ok(after[1].rect == Rect(0, 0, 20, 20), 'region follows the new transform')
end)

F.section('input: gesture')

F.test('a down followed by an up on the same node taps', function()
    local taps = 0
    local owner = laid_out(RenderGesture(box(40, 20), {
        on_tap = function() taps = taps + 1 end,
    }))
    owner:dispatch_pointer('down', Offset(5, 5))
    owner:dispatch_pointer('up', Offset(5, 5))
    F.eq(taps, 1, 'tap fired')
end)

F.test('legacy taps accept only nil and left button data', function()
    local taps, downs, ups = 0, 0, 0
    local owner = laid_out(RenderGesture(box(40, 20), {
        on_down = function() downs = downs + 1 end,
        on_up = function() ups = ups + 1 end,
        on_tap = function() taps = taps + 1 end,
    }))
    local function press(button)
        owner:dispatch_pointer('down', Offset(5, 5), button)
        owner:dispatch_pointer('up', Offset(5, 5), button)
    end

    press('middle')
    press('right')
    press('left')
    press(nil)

    F.eq(downs, 2, 'middle and right do not call on_down')
    F.eq(ups, 2, 'middle and right do not call on_up')
    F.eq(taps, 2, 'only left and nil data tap')
end)

F.test('does not tap when the release lands elsewhere', function()
    local taps = 0
    local owner = laid_out(RenderGesture(box(40, 20), {
        on_tap = function() taps = taps + 1 end,
    }))
    owner:dispatch_pointer('down', Offset(5, 5))
    owner:dispatch_pointer('up', Offset(500, 500))
    F.eq(taps, 0, 'no tap')
end)

F.test('wheel events reach the gesture with a delta', function()
    local deltas = {}
    local owner = laid_out(RenderGesture(box(40, 20), {
        on_wheel = function(_, delta) deltas[#deltas + 1] = delta end,
    }))
    owner:dispatch_pointer('wheel', Offset(5, 5), 1)
    owner:dispatch_pointer('wheel', Offset(5, 5), -1)
    F.eq(#deltas, 2, 'two wheel events')
    F.eq(deltas[1], 1, 'wheel up')
    F.eq(deltas[2], -1, 'wheel down')
end)

F.test('move drives enter and leave exactly once', function()
    local log = {}
    local owner = laid_out(RenderGesture(box(40, 20), {
        on_enter = function() log[#log + 1] = 'enter' end,
        on_leave = function() log[#log + 1] = 'leave' end,
    }))
    owner:dispatch_pointer('move', Offset(5, 5))
    owner:dispatch_pointer('move', Offset(5, 6))
    owner:dispatch_pointer('move', Offset(500, 500))
    F.eq(#log, 2, 'enter once, leave once')
    F.eq(log[1], 'enter', 'entered')
    F.eq(log[2], 'leave', 'left')
end)

F.test('clear_hover leaves every hovered node', function()
    local leaves = 0
    local owner = laid_out(RenderGesture(box(40, 20), {
        on_enter = function() end,
        on_leave = function() leaves = leaves + 1 end,
    }))
    owner:dispatch_pointer('move', Offset(5, 5))
    owner:clear_hover()
    F.eq(leaves, 1, 'left')
end)

F.section('input: wants_pointer')

F.test('reflects the handlers a node declares', function()
    local owner = laid_out(RenderGesture(box(10, 10), {
        on_tap = function() end,
    }))
    F.ok(owner:wants_pointer('down', Offset(5, 5)), 'wants down')
    F.ok(not owner:wants_pointer('wheel', Offset(5, 5)), 'ignores wheel')
    F.ok(not owner:wants_pointer('down', Offset(500, 500)), 'misses outside')
end)

F.test('expand grows the hit area beyond the child', function()
    local hits = 0
    local owner = laid_out(RenderGesture(box(10, 10), {
        expand = 5,
        on_tap = function() hits = hits + 1 end,
    }))
    F.ok(owner:wants_pointer('down', Offset(-3, -3)), 'inside the expanded area')
    F.ok(not owner:wants_pointer('down', Offset(-10, -10)), 'outside the expanded area')
    owner:dispatch_pointer('down', Offset(-3, -3))
    owner:dispatch_pointer('up', Offset(-3, -3))
    F.eq(hits, 1, 'tapped inside the expanded area')
end)

F.test('a press cancelled outside does not tap', function()
    local taps = 0
    local owner = laid_out(RenderGesture(box(40, 20), {
        on_tap = function() taps = taps + 1 end,
    }))
    owner:dispatch_pointer('down', Offset(5, 5))
    owner:dispatch_pointer('up', Offset(500, 500))
    F.eq(taps, 0, 'outside release cancels')
end)

F.section('input: pointer events and capture')

F.test('PointerEvent carries core and extension fields', function()
    local event = PointerEvent('down', Offset(2, 3), 'left', { device = 'mouse' })
    F.eq(event.type, 'down', 'type')
    F.ok(event.point == Offset(2, 3), 'point')
    F.eq(event.data, 'left', 'data')
    F.eq(event.device, 'mouse', 'extension field')
    local copied = PointerEvent({ type = 'move', point = Offset(4, 5), pressure = 0.5 })
    F.eq(copied.type, 'move', 'table constructor type')
    F.eq(copied.pressure, 0.5, 'table constructor extension')
end)

F.test('capture routes move and up outside the hit area', function()
    local events = {}
    local node = box(20, 20)
    ---@diagnostic disable-next-line: duplicate-set-field
    function node:wants_pointer(event)
        return event == 'down'
    end
    ---@diagnostic disable-next-line: duplicate-set-field
    function node:on_pointer(event, point)
        events[#events + 1] = event == 'down' and 'down'
            or event == 'move' and (point and 'move-point' or 'move-captured')
            or event == 'up' and (point and 'up-point' or 'up-captured')
        return event == 'down'
    end
    local owner = laid_out(node)
    owner:dispatch_pointer(PointerEvent('down', Offset(5, 5))) --[[@as PointerEvent]]
    F.ok(owner:has_pointer_capture(), 'capture is reported while mounted')
    owner:dispatch_pointer(PointerEvent('move', Offset(100, 100))) --[[@as PointerEvent]]
    owner:dispatch_pointer(PointerEvent('up', Offset(100, 100))) --[[@as PointerEvent]]
    F.eq(events[1], 'down', 'down delivered')
    F.eq(events[2], 'move-captured', 'captured move delivered')
    F.eq(events[3], 'up-captured', 'captured up delivered')
    F.ok(not owner:has_pointer_capture(), 'capture is released after up')
end)

F.test('a new down replaces capture without losing the new release', function()
    local taps = 0
    local owner = laid_out(RenderGesture(box(20, 20), {
        on_tap = function() taps = taps + 1 end,
    }))
    owner:dispatch_pointer('down', Offset(5, 5), 'left')
    owner:dispatch_pointer('down', Offset(6, 6), 'left')
    owner:dispatch_pointer('up', Offset(6, 6), 'left')
    F.eq(taps, 1, 'the replacement press receives its release')
end)

F.test('detached capture is cancelled before stale up dispatch', function()
    local old_events = {}
    local old_taps = 0
    local old = box(20, 20)
    -- This target is a deliberately dynamic capture test double.
    ---@diagnostic disable-next-line: duplicate-set-field
    function old:wants_pointer(event)
        return event == 'down'
    end
    ---@diagnostic disable-next-line: duplicate-set-field
    function old:on_pointer(event, point, data)
        old_events[#old_events + 1] = event
        if event == 'up' then
            old_taps = old_taps + 1
        end
        return event == 'down'
    end
    local root = RenderCustomPaint(nil, { child = old })
    local owner = laid_out(root)
    owner:dispatch_pointer('down', Offset(5, 5), 'left')
    F.ok(owner:has_pointer_capture(), 'capture starts on the old subtree')

    local replacement_ups = 0
    root:set_children({ RenderGesture(box(20, 20), {
        on_up = function() replacement_ups = replacement_ups + 1 end,
        on_tap = function() error('replacement tapped without a down') end,
    }) })
    F.ok(not owner:has_pointer_capture(), 'detached capture is cancelled by the query')
    owner:dispatch_pointer('up', Offset(5, 5), 'left')

    F.eq(old_events[1], 'down', 'old target received its down')
    F.eq(old_events[2], 'cancel', 'old target received cancellation')
    F.eq(old_events[3], nil, 'old target receives no stale up')
    F.eq(old_taps, 0, 'detached target cannot produce a stale tap')
    F.eq(replacement_ups, 0, 'stale up does not reach the replacement target')
end)

F.test('root replacement clears hover and capture state', function()
    local leaves = 0
    local old = RenderGesture(box(20, 20), {
        on_enter = function() end,
        on_leave = function() leaves = leaves + 1 end,
        on_tap = function() error('old root tapped after replacement') end,
    })
    local owner = laid_out(old)
    owner:dispatch_pointer('move', Offset(5, 5))
    owner:dispatch_pointer('down', Offset(5, 5), 'left')
    local replacement = RenderGesture(box(20, 20), { on_tap = function() end })
    owner:set_root(replacement)

    F.eq(leaves, 1, 'old hover receives leave')
    F.ok(not old.hovered, 'old hover is cleared')
    F.ok(not old.pressed, 'old capture is cancelled')
    F.ok(not owner:has_pointer_capture(), 'root replacement has no capture')
end)

F.test('clear_hover cancels and releases capture', function()
    local node = RenderGesture(box(20, 20), {
        on_tap = function() error('cancelled press tapped') end,
    })
    local owner = laid_out(node)
    owner:dispatch_pointer('down', Offset(5, 5))
    owner:clear_hover()
    owner:dispatch_pointer('up', Offset(5, 5))
    F.ok(not node.pressed, 'capture cancelled')
end)
