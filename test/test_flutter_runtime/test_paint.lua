-- Paint traversal, backend equivalence and exceptional save/restore boundaries.
---@diagnostic disable: undefined-field, inject-field, need-check-nil, param-type-mismatch
local F = require 'framework'
local geometry = require 'foundation.geometry'
local color_mod = require 'foundation.color'
local constraints_mod = require 'layout.constraints'
local context_mod = require 'render.painting_context'
local owner_mod = require 'render.pipeline_owner'
local record_mod = require 'backends.record'
local ass_mod = require 'backends.ass_canvas'
local sized_mod = require 'render.sized_box'
local decorated_mod = require 'render.decorated_box'
local offset_mod = require 'render.offset_box'
local transform_mod = require 'render.transform_box'
local scale_mod = require 'render.layout_scale_box'
local fitted_mod = require 'render.fitted_box'
local Offset, Size, Rect = geometry.Offset, geometry.Size, geometry.Rect
local Constraints = constraints_mod.Constraints
local PaintingContext = context_mod.PaintingContext
local RecordCanvas, AssCanvas = record_mod.RecordCanvas, ass_mod.AssCanvas

local variants = {
    { 'offset', function(child) return offset_mod.RenderOffsetBox(Offset(2, 3), child) end },
    { 'zero offset', function(child) return offset_mod.RenderOffsetBox(Offset.zero(), child) end },
    { 'transform', function(child)
        return transform_mod.RenderTransformBox(child, { scale = Size(2, 2), clip = true })
    end },
    { 'layout scale', function(child)
        return scale_mod.RenderLayoutScaleBox(child, { scale = Size(2, 2), clip = true })
    end },
    { 'fitted', function(child) return fitted_mod.RenderFittedBox(child, { clip = true }) end },
}

local function content()
    return sized_mod.RenderSizedBox(10, 5, decorated_mod.RenderDecoratedBox(
        decorated_mod.Decoration({ color = color_mod.Color.rgba255(255, 0, 0) })))
end

F.section('runtime: PaintingContext traversal and backend output')

for _, variant in ipairs(variants) do
    F.test(variant[1] .. ' traverses the context and preserves Record/ASS output', function()
        local child = content()
        local root = variant[2](child)
        root:layout(Constraints.loose(100, 100))
        local hit_before = root:hit_test(Offset(1, 1))
        local canvas = RecordCanvas()
        local context = PaintingContext(canvas)
        local visited = {}
        context.paint_child = function(self, node, offset)
            visited[#visited + 1] = node
            PaintingContext.paint_child(self, node, offset)
        end
        root:paint(context, Offset.zero())
        F.eq(visited[1], child, 'transformed child passes through context')
        F.eq(#visited, 2, 'all descendant edges pass through context')
        F.eq(canvas:count('draw_rect'), 1, 'visible content drawn exactly once')
        F.eq(canvas:count('save'), canvas:count('restore'), 'balanced canvas stack')
        local expected, actual = AssCanvas(), AssCanvas()
        for _, op in ipairs(canvas.ops) do
            expected[op.name](expected, unpack(op, 1, op.n))
        end
        root:paint(actual, Offset.zero())
        F.ok(#actual:text() > 0, 'ASS output is nonempty')
        F.eq(actual:text(), expected:text(), 'ASS agrees with recorded drawing operations')
        F.eq(root:hit_test(Offset(1, 1)), hit_before, 'painting does not change hit result')
    end)

    F.test(variant[1] .. ' restores the Canvas after a child throws', function()
        local child = content()
        child.__paint = function(self, canvas, offset) error('paint failure') end
        local root = variant[2](child)
        root:layout(Constraints.loose(100, 100))
        local canvas = AssCanvas()
        F.raises(function() root:paint(canvas, Offset.zero()) end, 'paint failure', 'error propagated')
        local clean = AssCanvas()
        local leaf = content()
        leaf:layout(Constraints.loose(100, 100))
        leaf:paint(canvas, Offset.zero())
        leaf:paint(clean, Offset.zero())
        F.eq(canvas:text(), clean:text(), 'no leaked clip or transform after failure')
    end)
end

F.test('clip scope restores even when clipping itself fails', function()
    local record = RecordCanvas()
    record.clip_rect = function() error('clip failure') end
    F.raises(function()
        PaintingContext(record):clip_rect_and_paint(Rect.from_ltwh(0, 0, 5, 5), function() end)
    end, 'clip failure', 'clip error propagated')
    F.eq(table.concat(record:names(), ','), 'save,restore', 'save restored on clip error')
end)

F.test('duplicate dirty requests coalesce traversal and paint-only skips layout', function()
    local root = content()
    local layouts, paints = 0, 0
    local layout, paint = root.__perform_layout, root.__paint
    root.__perform_layout = function(self, constraints)
        layouts = layouts + 1
        return layout(self, constraints)
    end
    root.__paint = function(self, canvas, offset)
        paints = paints + 1
        return paint(self, canvas, offset)
    end
    local owner = owner_mod.PipelineOwner(root)
    owner:set_viewport(Constraints.loose(100, 100))
    root:mark_needs_layout()
    root:mark_needs_layout()
    owner:flush_layout()
    owner:flush_paint(RecordCanvas())
    owner:flush_layout()
    owner:flush_paint(RecordCanvas())
    F.eq(layouts, 1, 'one layout traversal')
    F.eq(paints, 1, 'one paint traversal')
    root:mark_needs_paint()
    owner:flush_layout()
    owner:flush_paint(RecordCanvas())
    F.eq(layouts, 1, 'paint-only skips layout')
    F.eq(paints, 2, 'paint-only draws again')
    owner:dispose()
end)
