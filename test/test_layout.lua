-- Layout + render tree: the constraint protocol, the box set, the owner and
-- painting through a recording canvas.

-- See the note in test_widget.lua: the `std.class` / optional-ownership
-- diagnostics are disabled across the suite.
---@diagnostic disable: undefined-field, inject-field, need-check-nil, generic-constraint-mismatch, preferred-local-alias, unused

local F = require('framework')
local std = require('elxlibs.std')

local geometry = require('foundation.geometry')
local constraints_mod = require('layout.constraints')
local render_owner = require('render.render_owner')
local padding_mod = require('render.padding')
local align_mod = require('render.align')
local flex_mod = require('render.flex')
local stack_mod = require('render.stack')
local custom_paint_mod = require('render.custom_paint')
local record_mod = require('backends.record')

local Offset, Size, Rect, EdgeInsets = geometry.Offset, geometry.Size, geometry.Rect, geometry.EdgeInsets
local Constraints = constraints_mod.Constraints
local RenderOwner = render_owner.RenderOwner
local RenderPadding = padding_mod.RenderPadding
local RenderAlign = align_mod.RenderAlign
local RenderFlex = flex_mod.RenderFlex
local RenderStack = stack_mod.RenderStack
local RenderCustomPaint = custom_paint_mod.RenderCustomPaint
local RecordCanvas = record_mod.RecordCanvas

--- A fixed-size, non-drawing leaf.
---@param w number
---@param h number
local function box(w, h)
    return RenderCustomPaint(nil, { preferred_size = Size(w, h) })
end

--== Constraints ===========================================================

F.section('layout: Constraints')

F.test('constrains sizes and reports bounds', function()
    local c = Constraints(10, 20, 30, 40)
    F.close(c:constrain_width(5), 10, 'clamp below min')
    F.close(c:constrain_width(50), 20, 'clamp above max')
    F.close(c:constrain_height(35), 35, 'within range')
    F.ok(c:constrain_size(Size(5, 50)) == Size(10, 40), 'both axes clamped')
    F.ok(c:has_bounded_width() and c:has_bounded_height(), 'bounded')
    F.ok(not Constraints.expand():has_bounded_width(), 'expand is unbounded')
    F.ok(Constraints.expand():is_normalized(), 'expand is normalized')
end)

F.test('tight, loose and expand helpers', function()
    F.ok(Constraints.tight(4, 6):is_tight(), 'tight is tight')
    F.ok(Constraints.tight(4, 6) == Constraints(4, 4, 6, 6), 'tight values')
    F.ok(Constraints.tight_size(Size(4, 6)) == Constraints.tight(4, 6), 'tight_size')
    F.ok(Constraints.loose(10, 20) == Constraints(0, 10, 0, 20), 'loose values')
    F.ok(Constraints.loose(10, 20):loosen() == Constraints.loose(10, 20), 'loosen is idempotent')
end)

F.test('deflate shrinks by insets and never goes negative', function()
    local inner = Constraints(10, 100, 10, 100):deflate(EdgeInsets.all(10))
    F.ok(inner == Constraints(0, 80, 0, 80), 'deflated by 20px per axis')
    local tight = Constraints.tight(10, 10):deflate(EdgeInsets.all(20))
    F.ok(tight == Constraints(0, 0, 0, 0), 'clamped at zero')
end)

--== box protocol ==========================================================

F.section('render: padding / align')

F.test('padding inflates the box and offsets the child', function()
    local child = box(50, 20)
    local node = RenderPadding(EdgeInsets(4, 8, 4, 8), child)
    node:layout(Constraints.expand())
    F.ok(node.size == Size(58, 36), 'size = child + insets')
    F.ok(child.size == Size(50, 20), 'child keeps its size')
    F.ok(child.parent_data.offset == Offset(4, 8), 'child offset by top-left inset')
end)

F.test('align sizes to the space and centers the child', function()
    local child = box(20, 10)
    local node = RenderAlign(Offset(0.5, 0.5), child)
    node:layout(Constraints.tight(100, 50))
    F.ok(node.size == Size(100, 50), 'fills bounded space')
    F.ok(child.parent_data.offset == Offset(40, 20), 'centered')
end)

F.test('align shrink-wraps on an unbounded axis', function()
    local child = box(20, 10)
    local node = RenderAlign(Offset(0.5, 0.5), child)
    node:layout(Constraints.expand())
    F.ok(node.size == Size(20, 10), 'sized to child')
end)

--== flex ==================================================================

F.section('render: flex')

F.test('row lays children out with spacing', function()
    local root = RenderFlex('row', {
        children = { box(20, 10), box(20, 10) },
        spacing = 10,
    })
    root:layout(Constraints.tight(100, 10))
    F.ok(root.size == Size(100, 10), 'fills the main axis')
    local a, b = root:children()[1], root:children()[2]
    F.ok(a.parent_data.offset == Offset(0, 0), 'first child')
    F.ok(b.parent_data.offset == Offset(30, 0), 'second child after spacing')
end)

F.test('main-alignment centers the content', function()
    local root = RenderFlex('row', {
        children = { box(20, 10), box(20, 10) },
        main_alignment = 'center',
    })
    root:layout(Constraints.tight(100, 10))
    local a, b = root:children()[1], root:children()[2]
    F.ok(a.parent_data.offset == Offset(30, 0), 'leading gap')
    F.ok(b.parent_data.offset == Offset(50, 0), 'second child')
end)

F.test('flex children share the remaining main space', function()
    local a, b, c = box(20, 10), box(0, 10), box(20, 10)
    b.parent_data.flex = 1
    local root = RenderFlex('row', { children = { a, b, c } })
    root:layout(Constraints.tight(200, 10))
    F.close(b.size.width, 160, 'flex child takes the remainder')
    F.ok(a.parent_data.offset == Offset(0, 0), 'a at the start')
    F.ok(b.parent_data.offset == Offset(20, 0), 'b after a')
    F.ok(c.parent_data.offset == Offset(180, 0), 'c pushed to the end')
end)

F.test('column stacks children and centers them on the cross axis', function()
    local root = RenderFlex('column', {
        children = { box(20, 10), box(40, 10) },
        cross_alignment = 'center',
    })
    root:layout(Constraints.tight(100, 100))
    F.ok(root.size == Size(100, 100), 'fills tight constraints')
    local a, b = root:children()[1], root:children()[2]
    F.ok(a.parent_data.offset == Offset(40, 0), 'first centered')
    F.ok(b.parent_data.offset == Offset(30, 10), 'second centered below')
end)

F.test('ignores flex on an unbounded main axis', function()
    local a, b = box(20, 10), box(20, 10)
    b.parent_data.flex = 1
    local root = RenderFlex('row', { children = { a, b } })
    root:layout(Constraints(0, math.huge, 0, 10))
    F.ok(root.size == Size(40, 10), 'shrink-wraps to content')
end)

--== stack =================================================================

F.section('render: stack')

F.test('overlays children, centered on the biggest one', function()
    local a, b = box(40, 40), box(10, 10)
    local root = RenderStack({ children = { a, b }, alignment = Offset(0.5, 0.5) })
    root:layout(Constraints.loose(100, 100))
    F.ok(root.size == Size(40, 40), 'sized to the biggest child')
    F.ok(a.parent_data.offset == Offset(0, 0), 'biggest child at the origin')
    F.ok(b.parent_data.offset == Offset(15, 15), 'smaller child centered')
end)

--== painting / hit testing ================================================

F.section('render: paint + hit test')

F.test('paints through a canvas with absolute coordinates', function()
    local canvas = RecordCanvas()
    local child = RenderCustomPaint(function(c, offset, size)
        c:draw_rect(Rect.from_offset_size(offset, size), nil --[[@as Paint]])
    end, { preferred_size = Size(10, 10) })
    local root = RenderPadding(EdgeInsets.all(5), child)
    root:layout(Constraints.expand())
    root:paint(canvas, Offset.zero())
    F.eq(canvas:count('draw_rect'), 1, 'one draw op')
    F.ok(canvas.ops[1][1] == Rect(5, 5, 15, 15), 'rect offset by the padding')
end)

F.test('hit test returns the deepest node under a point', function()
    local leaf = box(10, 10)
    local root = RenderPadding(EdgeInsets.all(5), leaf)
    root:layout(Constraints.expand())
    F.ok(root:hit_test(Offset(7, 7)) == leaf, 'inside the child')
    F.ok(root:hit_test(Offset(1, 1)) == root, 'inside the padding only')
    F.ok(root:hit_test(Offset(100, 100)) == nil, 'outside the node')
end)

--== owner =================================================================

F.section('render: owner')

F.test('drives layout and reports dirty to the host', function()
    local root = box(30, 20)
    local owner = RenderOwner(root)
    owner:set_viewport(Constraints.tight(80, 60))
    F.ok(owner:needs_layout(), 'dirty after a viewport change')
    owner:layout()
    F.ok(not owner:needs_layout(), 'clean after layout')
    F.ok(root.size == Size(80, 60), 'laid out to the viewport')

    local dirty = 0
    owner.on_dirty = function() dirty = dirty + 1 end
    root:mark_needs_layout()
    F.ok(owner:needs_layout(), 'child dirt propagates to the owner')
    F.eq(dirty, 1, 'on_dirty fired')
end)
