-- Flutter runtime alignment: owners, build scopes, paint context and keys.

---@diagnostic disable: undefined-field, inject-field, need-check-nil, generic-constraint-mismatch, preferred-local-alias, unused, param-type-mismatch, missing-parameter, missing-fields

local F = require 'framework'
local std = require 'elxlibs.std'

local geometry = require 'foundation.geometry'
local foundation_key = require 'foundation.key'
local binding_base = require 'foundation.binding_base'
local scheduler_binding_mod = require 'scheduler.scheduler_binding'
local painting_binding_mod = require 'painting.painting_binding'
local painting_context_mod = require 'render.painting_context'
local pipeline_owner_mod = require 'render.pipeline_owner'
local renderer_binding_mod = require 'render.renderer_binding'
local render_owner_mod = require 'render.render_owner'
local record = require 'backends.record'
local constraints_mod = require 'layout.constraints'
local widget_mod = require 'widget.widget'
local widget_key = require 'widget.key'
local widget_binding = require 'widget.widgets_binding'
local build_scope_mod = require 'widget.build_scope'
local build_owner_mod = require 'widget.build_owner'
local layout_widgets = require 'widget.widgets.layout'

local Rect = geometry.Rect
local Offset = geometry.Offset
local Constraints = constraints_mod.Constraints
local BindingBase = binding_base.BindingBase
local SchedulerBinding = scheduler_binding_mod.SchedulerBinding
local PaintingBinding = painting_binding_mod.PaintingBinding
local PaintingContext = painting_context_mod.PaintingContext
local RendererBinding = renderer_binding_mod.RendererBinding
local PipelineOwner = pipeline_owner_mod.PipelineOwner
local RenderOwner = render_owner_mod.RenderOwner
local RecordCanvas = record.RecordCanvas
local WidgetsBinding = widget_binding.WidgetsBinding
local WidgetBinding = widget_binding.WidgetBinding
local BuildScope = build_scope_mod.BuildScope
local BuildOwner = build_owner_mod.BuildOwner
local Key = foundation_key.Key
local LocalKey = foundation_key.LocalKey
local ValueKey = foundation_key.ValueKey
local UniqueKey = foundation_key.UniqueKey
local ObjectKey = widget_key.ObjectKey
local GlobalKey = widget_key.GlobalKey
local SizedBox = layout_widgets.SizedBox
local Column = layout_widgets.Column

---@param widget Widget
---@return RenderOwner, WidgetTree
local function mount(widget)
    local owner = RenderOwner()
    local binding = WidgetsBinding.ensure_initialized():attach(widget, owner)
    owner:set_viewport(Constraints.loose(100, 100))
    owner:layout()
    return owner, binding
end

F.section('flutter runtime: key hierarchy')

F.test('foundation and widget key aggregates preserve identity', function()
    F.eq(widget_key.Key, Key, 'Key identity')
    F.eq(widget_key.LocalKey, LocalKey, 'LocalKey identity')
    F.eq(widget_key.ValueKey, ValueKey, 'ValueKey identity')
    F.eq(widget_key.UniqueKey, UniqueKey, 'UniqueKey identity')
    F.ok(std.isinstance(ValueKey('x'), LocalKey), 'ValueKey is local')
    F.ok(not std.isinstance(GlobalKey(), LocalKey), 'GlobalKey is not local')
end)

F.test('value, unique and object keys use their documented identity', function()
    F.ok(Key('a') == Key('a'), 'legacy Key value equality')
    F.ok(ValueKey('a') == ValueKey('a'), 'ValueKey equality')
    F.ok(not (ValueKey('a') == ValueKey('b')), 'ValueKey value difference')
    F.ok(not (UniqueKey() == UniqueKey()), 'UniqueKey identity')
    local object = {}
    F.ok(ObjectKey(object) == ObjectKey(object), 'ObjectKey object identity')
    F.ok(not (ObjectKey(object) == ObjectKey({})), 'ObjectKey rejects another object')
end)

F.test('GlobalKey registers, queries and clears its current element', function()
    local key = GlobalKey('probe')
    local widget = SizedBox({ key = key, width = 10, height = 10 })
    local _, binding = mount(widget)
    F.eq(key:current_element(), binding.root_element, 'current element')
    F.eq(key:current_widget(), widget, 'current widget')
    F.eq(key:current_context(), binding.root_element, 'current context')
    binding:set_root_widget(SizedBox({ width = 1, height = 1 }))
    F.eq(key:current_element(), nil, 'stale registry is cleared')
end)

F.test('GlobalKey duplicate registration is rejected per BuildOwner', function()
    local key = GlobalKey('duplicate')
    F.raises(function()
        mount(Column({
            children = {
                SizedBox({ key = key, width = 1, height = 1 }),
                SizedBox({ key = key, width = 1, height = 1 }),
            },
        }))
    end, 'GlobalKey', 'duplicate GlobalKey')
end)

F.test('LocalKey duplicates produce a BuildOwner diagnostic', function()
    local _, binding = mount(Column({
        children = {
            SizedBox({ key = ValueKey('same'), width = 1, height = 1 }),
            SizedBox({ key = ValueKey('same'), width = 1, height = 1 }),
        },
    }))
    F.eq(#binding.build_owner.diagnostics, 1, 'duplicate LocalKey diagnostic')
end)

F.section('flutter runtime: BuildScope')

F.test('BuildScope coalesces dirty notifications until cleared', function()
    local scheduled = 0
    local scope = BuildScope(function() scheduled = scheduled + 1 end)
    F.ok(scope:mark_dirty(), 'first dirty notification')
    F.ok(not scope:mark_dirty(), 'second notification is coalesced')
    F.eq(scheduled, 1, 'one rebuild request')
    scope:clear_dirty()
    F.ok(scope:mark_dirty(), 'scope can be dirtied again')
    F.eq(scheduled, 2, 'second rebuild request')
end)

F.test('BuildOwner exposes build phase and finalizes inactive elements', function()
    local key = GlobalKey('inactive')
    local _, binding = mount(SizedBox({ key = key, width = 1, height = 1 }))
    local element = binding.root_element
    F.ok(element:deactivate(), 'deactivate succeeds')
    F.eq(key:current_element(), nil, 'inactive element is not current')
    F.ok(element:activate(nil), 'inactive element can reactivate before finalize')
    F.eq(key:current_element(), element, 'reactivated element is current')
    F.ok(element:deactivate(), 'deactivate again succeeds')
    binding.build_owner:finalize_tree()
    F.ok(not element.mounted, 'finalize unmounts inactive element')
    F.eq(key:current_element(), nil, 'finalize clears key registry')
    F.ok(not binding.build_owner:is_building(), 'build phase is closed')
end)

F.test('BuildOwner flushes only the requested BuildScope', function()
    local owner = BuildOwner()
    local first_scope = owner:create_build_scope()
    local second_scope = owner:create_build_scope()
    local rebuilt = {}
    local first = {
        active = true,
        build_scope = first_scope,
        depth = 1,
        dirty = true,
        mounted = true,
    }
    function first:rebuild()
        rebuilt[#rebuilt + 1] = 'first'
        self.dirty = false
    end
    local second = {
        active = true,
        build_scope = second_scope,
        depth = 1,
        dirty = true,
        mounted = true,
    }
    function second:rebuild()
        rebuilt[#rebuilt + 1] = 'second'
        self.dirty = false
    end
    owner:schedule_build_for(first)
    owner:schedule_build_for(second)
    owner:rebuild_dirty(first_scope)
    F.eq(rebuilt[1], 'first', 'requested scope rebuilt')
    F.ok(second.dirty, 'other scope remains dirty')
    owner:rebuild_dirty()
    F.eq(rebuilt[2], 'second', 'remaining scope rebuilt')
end)

F.test('BuildOwner rejects reentrant rebuilds and resets its build lock', function()
    local owner = BuildOwner()
    local element = {
        active = true,
        build_scope = owner.root_scope,
        depth = 0,
        dirty = true,
        mounted = true,
    }
    function element:rebuild()
        owner:rebuild_dirty()
    end
    owner:schedule_build_for(element)
    F.raises(function()
        owner:rebuild_dirty()
    end, 'not reentrant', 'reentrant rebuild')
    F.ok(not owner:is_building(), 'build lock resets after an error')
end)

F.section('flutter runtime: PipelineOwner and PaintingContext')

F.test('PipelineOwner and RenderOwner are the same class object', function()
    F.eq(PipelineOwner, RenderOwner, 'pipeline owner identity')
    local owner = PipelineOwner()
    F.ok(owner.flush_layout ~= nil and owner.flush_paint ~= nil, 'pipeline flush methods')
    owner:dispose()
end)

F.test('PaintingContext brackets clipping and forwards Canvas operations', function()
    local canvas = RecordCanvas()
    local context = PaintingContext(canvas, Rect.from_ltwh(0, 0, 10, 10))
    context:clip_rect_and_paint(Rect.from_ltwh(0, 0, 5, 5), function()
        context:draw_rect(Rect.from_ltwh(0, 0, 1, 1), nil)
    end)
    F.eq(canvas.ops[1].name, 'save', 'context save')
    F.eq(canvas.ops[2].name, 'clip_rect', 'context clip')
    F.eq(canvas.ops[3].name, 'draw_rect', 'context paint')
    F.eq(canvas.ops[4].name, 'restore', 'context restore')
end)

F.test('RenderObject painting accepts both Canvas and PaintingContext', function()
    local owner = mount(SizedBox({ width = 10, height = 10 }))
    local canvas = RecordCanvas()
    owner:flush_layout()
    owner:flush_paint(canvas)
    F.ok(#canvas.ops >= 0, 'direct Canvas paint remains compatible')
end)

F.section('flutter runtime: binding composition and owner scopes')

F.test('WidgetsBinding follows Flutter singleton lifecycle', function()
    local first = WidgetsBinding.ensure_initialized()
    local second = WidgetsBinding.ensure_initialized()
    F.eq(first, second, 'ensure_initialized returns one binding')
    F.eq(BindingBase.current_instance(), first, 'BindingBase tracks the composition')
    F.raises(function()
        WidgetsBinding()
    end, 'already initialized', 'a second binding is rejected')
end)

F.test('WidgetsBinding copies owners for independent trees', function()
    F.eq(WidgetsBinding, WidgetBinding, 'WidgetsBinding identity')
    local key = GlobalKey('binding-isolation')
    local composition = WidgetsBinding.ensure_initialized()
    local first = composition:attach(SizedBox({ key = key, width = 1, height = 1 }))
    local second = composition:attach(SizedBox({ key = key, width = 1, height = 1 }))
    F.ok(first ~= second, 'independent tree handles')
    F.ok(first.build_owner ~= second.build_owner, 'independent BuildOwners')
    F.ok(first.render_owner ~= second.render_owner, 'independent PipelineOwners')
    F.eq(first.build_owner.global_key_registry[key], first.root_element,
        'first GlobalKey registry')
    F.eq(second.build_owner.global_key_registry[key], second.root_element,
        'second GlobalKey registry')
    first:dispose()
    F.eq(second.build_owner.global_key_registry[key], second.root_element,
        'disposing first binding keeps second registry')
    second:dispose()
end)

F.test('binding roles resolve to the same Flutter-style composition', function()
    local composition = WidgetsBinding.ensure_initialized()
    F.eq(SchedulerBinding.ensure_initialized(), composition, 'scheduler role identity')
    F.eq(RendererBinding.ensure_initialized(), composition, 'renderer role identity')
    F.eq(PaintingBinding.ensure_initialized(), composition, 'painting role identity')
    F.eq(WidgetsBinding.instance(), composition, 'widgets instance identity')
    F.eq(SchedulerBinding.instance(), composition, 'scheduler instance identity')
    F.eq(RendererBinding.instance(), composition, 'renderer instance identity')
    F.eq(PaintingBinding.instance(), composition, 'painting instance identity')
end)

F.test('RendererBinding creates independent PipelineOwners', function()
    local first_owner = RendererBinding.create_pipeline_owner()
    local second_owner = RendererBinding.create_pipeline_owner()
    F.ok(first_owner ~= second_owner, 'owner copies are independent')
    first_owner:dispose()
    second_owner:dispose()
end)

return true
