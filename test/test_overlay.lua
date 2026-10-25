-- N2 logical Overlay runtime: entry lifecycle, occlusion and plan updates.

---@diagnostic disable: undefined-field, inject-field, need-check-nil, unused, generic-constraint-mismatch

local F = require('framework')
local std = require('elxlibs.std')

local constraints_mod = require('layout.constraints')
local text_layout = require('text.text_layout')
local render_owner = require('render.render_owner')
local binding_mod = require('widget.binding')
local widget_mod = require('widget.widget')
local state_mod = require('widget.state')
local basic_widgets = require('widget.widgets.basic')
local overlay_mod = require('widget.overlay')
local ambient_mod = require('widget.ambient')
local record_mod = require('backends.record')

local Constraints = constraints_mod.Constraints
local TextLayout = text_layout.TextLayout
local RenderOwner = render_owner.RenderOwner
local WidgetBinding = binding_mod.WidgetBinding
local StatefulWidget = widget_mod.StatefulWidget
local State = state_mod.State
local Text = basic_widgets.Text
local Overlay = overlay_mod.Overlay
local OverlayEntry = overlay_mod.OverlayEntry
local FixedLayout = std.class.new('test.overlay.FixedLayout', { TextLayout })
local RecordCanvas = record_mod.RecordCanvas

function FixedLayout:line_width(line, style)
    return #line * style.font_size * 0.5
end
text_layout.set_default(FixedLayout())

local function mount(widget)
    local owner = RenderOwner()
    local binding = WidgetBinding.ensure_initialized():attach(widget, owner)
    owner:set_viewport(Constraints.tight(320, 180))
    owner:layout()
    return owner, binding
end

local ProbeState = std.class.new('test.overlay.ProbeState', { State })
function ProbeState:init_state()
    self.init_count = (self.init_count or 0) + 1
    self.disposed = false
end
function ProbeState:dispose()
    self.disposed = true
end
function ProbeState:build()
    return Text(self.widget.label)
end

local Probe = std.class.new('test.overlay.Probe', { StatefulWidget })
function Probe:__init(options)
    options = options or {}
    self.key = options.key
    self.label = options.label
end
function Probe:create_state()
    return ProbeState()
end

F.section('overlay: entry lifecycle')

F.test('entry builders run in mounted context and keep one content mount', function()
    local build_count = 0
    local context_mounted = false
    local entry = OverlayEntry({
        builder = function(context)
            build_count = build_count + 1
            context_mounted = context.mounted
            local scope = Overlay.of(context)
            F.ok(scope ~= nil, 'Overlay.of resolves from the entry context')
            return Probe({ key = 'stable', label = 'entry' })
        end,
    })
    local _, binding = mount(Overlay({ initial_entries = { entry } }))
    F.ok(context_mounted, 'builder received a mounted BuildContext')
    F.ok(entry:is_mounted(), 'entry reports a mounted content element')
    local initial_builds = build_count
    entry:mark_needs_build()
    binding:flush_build()
    F.ok(build_count > initial_builds, 'mark_needs_build reruns the builder')
    F.ok(entry:is_mounted(), 'entry remains mounted after rebuild')
end)

F.test('opaque entries occlude without disposing maintain_state content', function()
    local bottom = OverlayEntry({
        builder = function()
            return Probe({ key = 'bottom', label = 'bottom' })
        end,
        maintain_state = true,
    })
    local top = OverlayEntry({
        builder = function()
            return Probe({ key = 'top', label = 'top' })
        end,
        opaque = true,
    })
    local owner, binding = mount(Overlay({ initial_entries = { bottom, top } }))
    local bottom_state = nil
    local function find_probe(element, key)
        if element.widget and element.widget.__class == Probe and element.widget.key == key then
            return element.state
        end
        for _, child in ipairs(element:element_children()) do
            local found = find_probe(child, key)
            if found then
                return found
            end
        end
        return nil
    end
    bottom_state = find_probe(binding.root_element, 'bottom')
    F.ok(bottom_state ~= nil and bottom_state:is_mounted(), 'bottom state initially mounted')
    local plan = top._overlay.last_plan
    F.ok(plan ~= nil, 'overlay publishes a plan')
    if plan then
        F.ok(plan.entries[1].occluded, 'opaque top entry occludes the lower entry')
        F.ok(not plan.entries[1].paint and not plan.entries[1].input,
            'occluded entry loses paint and input eligibility')
    end
    top:set_visible(false)
    binding:flush_build()
    owner:layout()
    F.ok(bottom_state:is_mounted(), 'maintain_state keeps the lower content mounted')
end)

F.test('non-maintained occluded entries unmount and dispose State', function()
    local disposed = false
    local DisposableState = std.class.new('test.overlay.DisposableState', { State })
    function DisposableState:dispose()
        disposed = true
    end
    function DisposableState:build()
        return Text('disposable')
    end
    local Disposable = std.class.new('test.overlay.Disposable', { StatefulWidget })
    function Disposable:create_state()
        return DisposableState()
    end

    local bottom = OverlayEntry({
        builder = function()
            return Disposable({ key = 'disposable' })
        end,
        maintain_state = false,
    })
    local top = OverlayEntry({
        builder = function()
            return Text('opaque')
        end,
        opaque = true,
    })
    local _, binding = mount(Overlay({ initial_entries = { bottom, top } }))
    F.ok(not bottom:is_mounted(), 'non-maintained occluded entry is not mounted')
    top:set_visible(false)
    binding:flush_build()
    F.ok(bottom:is_mounted(), 'entry mounts when occlusion is removed')
    top:set_visible(true)
    binding:flush_build()
    F.ok(disposed, 'content State disposes when entry becomes occluded')
end)

F.test('removing an entry disposes its subtree on the next build', function()
    local disposed = false
    local DisposableState = std.class.new('test.overlay.RemoveState', { State })
    function DisposableState:dispose()
        disposed = true
    end
    function DisposableState:build()
        return Text('remove')
    end
    local Disposable = std.class.new('test.overlay.Remove', { StatefulWidget })
    function Disposable:create_state()
        return DisposableState()
    end
    local entry = OverlayEntry({ builder = function() return Disposable() end })
    local _, binding = mount(Overlay({ initial_entries = { entry } }))
    F.ok(entry:is_mounted(), 'entry is mounted before removal')
    F.ok(entry:remove(), 'remove accepts an attached entry')
    F.ok(not disposed, 'removal waits for the build flush')
    binding:flush_build()
    F.ok(disposed, 'removed entry State is disposed')
    F.ok(not entry:is_mounted(), 'removed entry is no longer mounted')
end)

F.test('hidden maintained entries paint no output and expose no pointer regions', function()
    local entry = OverlayEntry({
        builder = function()
            return Probe({ label = 'hidden' })
        end,
    })
    local owner, binding = mount(Overlay({ initial_entries = { entry } }))
    local canvas = RecordCanvas()
    owner:paint(canvas)
    local before = #canvas.ops
    entry:set_visible(false)
    binding:flush_build()
    owner:layout()
    owner:paint(canvas)
    F.eq(#canvas.ops, before, 'hidden entry contributes no paint operations')
    F.eq(#owner:pointer_regions(), 0, 'hidden entry contributes no input regions')
end)
