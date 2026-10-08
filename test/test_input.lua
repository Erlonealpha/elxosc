-- Pointer routing: path resolution, gesture dispatch and hover tracking.

-- See the note in test_widget.lua: the `std.class` / optional-ownership
-- diagnostics are disabled across the suite.
---@diagnostic disable: undefined-field, inject-field, need-check-nil, generic-constraint-mismatch, preferred-local-alias, unused

local F = require('framework')

local geometry = require('foundation.geometry')
local constraints_mod = require('layout.constraints')
local render_owner = require('render.render_owner')
local custom_paint = require('render.custom_paint')
local gesture_mod = require('render.gesture')
local padding_mod = require('render.padding')

local Offset, Size, EdgeInsets = geometry.Offset, geometry.Size, geometry.EdgeInsets
local Constraints = constraints_mod.Constraints
local RenderOwner = render_owner.RenderOwner
local RenderCustomPaint = custom_paint.RenderCustomPaint
local RenderGesture = gesture_mod.RenderGesture
local RenderPadding = padding_mod.RenderPadding

---@param w number
---@param h number
local function box(w, h)
    return RenderCustomPaint(nil, { preferred_size = Size(w, h) })
end

---@param node RenderObject
---@return RenderOwner
local function laid_out(node)
    local owner = RenderOwner(node)
    owner:set_viewport(Constraints.loose(200, 200))
    owner:layout()
    return owner
end

F.section('input: pointer path')

F.test('lists nodes deepest-first with local points', function()
    local leaf = box(10, 10)
    local root = RenderPadding(EdgeInsets.all(5), leaf)
    root:layout(Constraints.expand())
    local path = root:pointer_path(Offset(7, 7))
    F.eq(#path, 2, 'leaf + padding')
    F.ok(path[1].node == leaf, 'deepest first')
    F.ok(path[1].point == Offset(2, 2), 'point converted to leaf space')
    F.ok(path[2].node == root, 'ancestor last')
end)

F.test('is empty when the point misses the tree', function()
    local node = box(10, 10)
    node:layout(Constraints.expand())
    F.eq(#node:pointer_path(Offset(100, 100)), 0, 'no hit')
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
