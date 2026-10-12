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
local fitted_mod = require('render.fitted_box')
local transform_box_mod = require('render.transform_box')
local layout_scale_box_mod = require('render.layout_scale_box')
local custom_paint_mod = require('render.custom_paint')
local record_mod = require('backends.record')
local ass_canvas = require('backends.ass_canvas')

local Offset, Size, Rect, EdgeInsets = geometry.Offset, geometry.Size, geometry.Rect, geometry.EdgeInsets
local Constraints = constraints_mod.Constraints
local RenderOwner = render_owner.RenderOwner
local RenderPadding = padding_mod.RenderPadding
local RenderAlign = align_mod.RenderAlign
local RenderFlex = flex_mod.RenderFlex
local RenderStack = stack_mod.RenderStack
local RenderFittedBox = fitted_mod.RenderFittedBox
local RenderTransformBox = transform_box_mod.RenderTransformBox
local RenderLayoutScaleBox = layout_scale_box_mod.RenderLayoutScaleBox
local RenderCustomPaint = custom_paint_mod.RenderCustomPaint
local RecordCanvas = record_mod.RecordCanvas
local AssCanvas = ass_canvas.AssCanvas

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
    F.ok(c:has_tight_width() == false and c:has_tight_height() == false, 'not tight')
    F.ok(c:is_satisfied_by(Size(15, 35)), 'satisfied')
    F.ok(not c:is_satisfied_by(Size(5, 35)), 'too narrow is unsatisfied')
    F.ok(c:biggest() == Size(20, 40) and c:smallest() == Size(10, 30), 'biggest / smallest')
end)

F.test('tight, loose and expand helpers', function()
    F.ok(Constraints.tight(4, 6):is_tight(), 'tight is tight')
    F.ok(Constraints.tight(4, 6):has_tight_width(), 'tight width')
    F.ok(Constraints.tight(4, 6) == Constraints(4, 4, 6, 6), 'tight values')
    F.ok(Constraints.tight_size(Size(4, 6)) == Constraints.tight(4, 6), 'tight_size')
    F.ok(Constraints.loose(10, 20) == Constraints(0, 10, 0, 20), 'loose values')
    F.ok(Constraints.loose(10, 20):loosen() == Constraints.loose(10, 20), 'loosen is idempotent')
    F.ok(Constraints.tight_for({ width = 7 }) == Constraints(7, 7, 0, math.huge), 'tight_for width')
    F.ok(Constraints.tight_for({}) == Constraints(0, math.huge, 0, math.huge), 'tight_for none')
end)

F.test('unbounded versus expand', function()
    local unbounded = Constraints.unbounded()
    F.ok(not unbounded:has_bounded_width() and not unbounded:has_bounded_height(), 'unbounded')
    F.ok(not unbounded:is_tight(), 'unbounded is not tight')
    F.ok(not unbounded:has_infinite_width(), 'unbounded is not infinite')
    F.ok(unbounded:is_normalized(), 'unbounded is normalized')

    local expand = Constraints.expand()
    F.ok(not expand:has_bounded_width(), 'expand is unbounded (max is infinity)')
    F.ok(expand:has_infinite_width() and expand:has_infinite_height(), 'expand is infinite')
    F.ok(expand:is_tight(), 'expand is tightly infinite')
    F.ok(Constraints.expand(30, 40) == Constraints(30, 30, 40, 40), 'expand(width, height)')
end)

F.test('enforce intersects instead of replacing', function()
    -- The doc's ConstrainedBox examples 9-12: additional constraints are
    -- imposed on top of the parent's, not swapped in.
    local parent = Constraints.tight(300, 85)
    local additional = Constraints(70, 150, 70, 150)
    F.ok(additional:enforce(parent) == Constraints(300, 300, 85, 85), 'tight parent wins')
    local loose = Constraints.loose(300, 300)
    F.ok(additional:enforce(loose) == Constraints(70, 150, 70, 150), 'loose parent keeps the box')
    F.ok(Constraints.tight_for({ width = 1000 }):enforce(loose)
        == Constraints(300, 300, 0, 300), 'a huge width is clamped to the parent max')
    F.ok(additional:enforce(Constraints.loose(300, 85))
        == Constraints(70, 150, 70, 85), 'each axis is clamped independently')
end)

F.test('tighten and aspect-ratio constraint', function()
    local c = Constraints(0, 100, 0, 100)
    F.ok(c:tighten({ width = 40 }) == Constraints(40, 40, 0, 100), 'tighten width')
    F.ok(c:tighten({ width = 400 }) == Constraints(100, 100, 0, 100), 'tighten clamps to max')
    F.ok(Constraints.tight(50, 50):constrain_size_and_attempt_to_preserve_aspect_ratio(Size(10, 90))
        == Size(50, 50), 'tight constraints win')
    F.ok(Constraints.loose(100, 100):constrain_size_and_attempt_to_preserve_aspect_ratio(Size(200, 100))
        == Size(100, 50), 'shrunk preserving the ratio')
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
    node:layout(Constraints.unbounded())
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
    node:layout(Constraints.unbounded())
    F.ok(node.size == Size(20, 10), 'sized to child')
end)

F.section('render: fitted box')

F.test('composes fitted scale and crop translation consistently', function()
    local child = RenderCustomPaint(function(canvas, offset, size)
        canvas:draw_rect(Rect.from_offset_size(offset, size), nil --[[@as Paint]])
    end, { preferred_size = Size(400, 200) })
    local root = RenderFittedBox(child, { fit = 'cover' })
    root:layout(Constraints.tight(100, 100))
    local canvas = AssCanvas()
    root:paint(canvas, Offset.zero())
    F.contains(canvas:text(), 'm -400 0 l 1200 0 l 1200 800 l -400 800 c',
        'cover maps the cropped source through scale and translation')
end)

F.test('fitted box input reverses scale and crop and honors letterbox bounds', function()
    local cover_child = box(400, 200)
    local cover = RenderFittedBox(cover_child, { fit = 'cover' })
    cover:layout(Constraints.tight(100, 100))
    local cover_path = cover:pointer_path(Offset(10, 10))
    F.eq(cover_path[1].node, cover_child, 'cover point reaches child')
    F.eq(cover_path[1].point, Offset(120, 20), 'cover point is inverse mapped')

    local contain_child = box(200, 100)
    local contain = RenderFittedBox(contain_child, { fit = 'contain' })
    contain:layout(Constraints.tight(100, 100))
    F.eq(#contain:pointer_path(Offset(10, 10)), 1, 'letterbox is not a child hit')
    local contain_path = contain:pointer_path(Offset(10, 30))
    F.eq(contain_path[1].node, contain_child, 'content area reaches child')
    F.eq(contain_path[1].point, Offset(20, 10), 'contain point is inverse mapped')
end)

F.test('optional fitted clipping is emitted in the box coordinate space', function()
    local child = RenderCustomPaint(function(canvas, offset, size)
        canvas:draw_rect(Rect.from_offset_size(offset, size), nil --[[@as Paint]])
    end, { preferred_size = Size(200, 100) })
    local root = RenderFittedBox(child, { fit = 'none', clip = true })
    root:layout(Constraints.tight(100, 100))
    local canvas = AssCanvas()
    root:paint(canvas, Offset.zero())
    F.contains(canvas:text(), '\\clip(0,0,100,100)', 'clip follows the fitted box')
end)

F.test('rejects unsupported fitted options', function()
    F.raises(function()
        ---@diagnostic disable-next-line: param-type-mismatch
        RenderFittedBox(nil, { fit = 'rotate' })
    end,
        'not supported', 'fit option')
    F.raises(function()
        ---@diagnostic disable-next-line: param-type-mismatch
        RenderFittedBox(nil, { clip = 'yes' })
    end,
        'boolean', 'clip option')
end)

F.section('render: finite transform boxes')

F.test('TransformBox preserves layout size and paints a positive axis scale', function()
    local child = RenderCustomPaint(function(canvas, offset, size)
        canvas:draw_rect(Rect.from_offset_size(offset, size), nil --[[@as Paint]])
    end, { preferred_size = Size(10, 5) })
    local root = RenderTransformBox(child, {
        scale = Size(2, 1.5),
        alignment = Offset(0, 0),
        clip = true,
    })
    root:layout(Constraints.unbounded())
    F.eq(root.size, Size(10, 5), 'paint-only scale preserves layout size')
    F.eq(child.size, Size(10, 5), 'child keeps its natural size')

    local canvas = AssCanvas()
    root:paint(canvas, Offset.zero())
    F.contains(canvas:text(), '\\clip(0,0,10,5)', 'TransformBox clip')
    F.contains(canvas:text(), 'm 0 0 l 160 0 l 160 60', 'TransformBox scales geometry')
end)

F.test('TransformBox reverses input coordinates through its scale', function()
    local child = box(10, 5)
    local root = RenderTransformBox(child, {
        scale = Size(2, 2),
        alignment = Offset(0, 0),
    })
    root:layout(Constraints.unbounded())
    local path = root:pointer_path(Offset(4, 2))
    F.eq(path[1].node, child, 'scaled point reaches the child')
    F.close(path[1].point.x, 2, 'inverse x scale')
    F.close(path[1].point.y, 1, 'inverse y scale')
    local outside = root:pointer_path(Offset(20, 2))
    F.eq(#outside, 0, 'input remains clipped to the logical box')
end)

F.test('nested TransformBoxes compose paint and input mappings', function()
    local leaf = box(10, 5)
    local inner = RenderTransformBox(leaf, {
        scale = Size(3, 2),
        alignment = Offset(0, 0),
    })
    local outer = RenderTransformBox(inner, {
        scale = Size(2, 4),
        alignment = Offset(0, 0),
    })
    outer:layout(Constraints.unbounded())
    local path = outer:pointer_path(Offset(6, 4))
    F.eq(path[1].node, leaf, 'nested point reaches the leaf')
    F.eq(path[1].point, Offset(1, 0.5), 'nested inverse scales compose')
    F.eq(path[2].node, inner, 'inner transform is in the path')
    F.eq(path[3].node, outer, 'outer transform is in the path')
end)

F.test('LayoutScaleBox maps constraints and reports the scaled child size', function()
    local child = box(80, 40)
    local root = RenderLayoutScaleBox(child, {
        scale = Size(0.5, 2),
        alignment = Offset(0, 1),
    })
    root:layout(Constraints.tight(100, 100))
    F.eq(child.size, Size(200, 50), 'child receives inverse parent constraints')
    F.eq(root.size, Size(100, 100), 'scaled child is constrained by the parent')

    local path = root:pointer_path(Offset(25, 75))
    F.eq(path[1].node, child, 'layout-scaled point reaches the child')
    F.eq(path[1].point, Offset(50, 37.5), 'layout scale inverse mapping')
end)

F.test('LayoutScaleBox preserves natural sizing under unbounded constraints', function()
    local child = box(30, 10)
    local root = RenderLayoutScaleBox(child, { scale = Size(2, 0.5) })
    root:layout(Constraints.unbounded())
    F.eq(child.size, Size(30, 10), 'unbounded child keeps its natural size')
    F.eq(root.size, Size(60, 5), 'unbounded box reports scaled natural size')
end)

F.test('finite transform boxes reject invalid scales and alignments', function()
    F.raises(function()
        RenderTransformBox(nil, { scale = Size(0, 1) })
    end, 'positive finite', 'TransformBox rejects zero scale')
    F.raises(function()
        RenderLayoutScaleBox(nil, { scale = Size(-1, 1) })
    end, 'positive finite', 'LayoutScaleBox rejects negative scale')
    F.raises(function()
        RenderTransformBox(nil, { alignment = Offset(0 / 0, 0.5) })
    end, 'between 0 and 1', 'TransformBox rejects NaN alignment')
    F.raises(function()
        RenderLayoutScaleBox(nil, { alignment = Offset(0.5, math.huge) })
    end, 'between 0 and 1', 'LayoutScaleBox rejects infinite alignment')
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

F.test('an Expanded child on an unbounded main axis is an error', function()
    local a, b = box(20, 10), box(20, 10)
    b.parent_data.flex = 1
    local root = RenderFlex('row', { children = { a, b } })
    F.raises(function() root:layout(Constraints(0, math.huge, 0, 10)) end,
        'unbounded', 'flex on an unbounded main axis')
end)

F.test('a loose flexible child shrink-wraps on an unbounded main axis', function()
    local a, b = box(20, 10), box(20, 10)
    b.parent_data.flex = 1
    b.parent_data.fit = 'loose'
    local root = RenderFlex('row', { children = { a, b }, main_axis_size = 'min' })
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
    root:layout(Constraints.unbounded())
    root:paint(canvas, Offset.zero())
    F.eq(canvas:count('draw_rect'), 1, 'one draw op')
    F.ok(canvas.ops[1][1] == Rect(5, 5, 15, 15), 'rect offset by the padding')
end)

F.test('hit test returns the deepest node under a point', function()
    local leaf = box(10, 10)
    local root = RenderPadding(EdgeInsets.all(5), leaf)
    root:layout(Constraints.unbounded())
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
