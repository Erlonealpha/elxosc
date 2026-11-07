-- Framework phase benchmark. Runs in a standalone LuaJIT, without mp/mp stub.
local support_mod = require 'test.support'
support_mod.bootstrap('test')
local stats_mod = require 'tools.benchmark_support'
local scenes_mod = require 'tools.benchmark_scenes'
local binding_mod = require 'widget.widgets_binding'
local widget_mod = require 'widget.widget'
local state_mod = require 'widget.state'
local std = require 'elxlibs.std'
local record_mod = require 'backends.record'
local ass_mod = require 'backends.ass_canvas'
local layout_mod = require 'layout.constraints'
local text_mod = require 'text.text_layout'
local ass_layout_mod = require 'backends.ass_text_layout'
local geometry_mod = require 'foundation.geometry'
local json_mod = require 'elxlibs.json'
local animation_mod = require 'tools.benchmark_animation'

local now = stats_mod.now
local StatefulWidget = widget_mod.StatefulWidget
local State = state_mod.State
local Constraints = layout_mod.Constraints
local iterations = assert(tonumber(arg[1]))
local warmup = assert(tonumber(arg[2]))
---@cast iterations integer
---@cast warmup integer
local output = assert(arg[3])

---@class _BenchmarkRootOptions
---@field scene string
---@field tick integer

---@class BenchmarkRoot : StatefulWidget
---@field scene string
---@field tick integer
---@overload fun(options: _BenchmarkRootOptions): self
local BenchmarkRoot = std.class.new('BenchmarkRoot', StatefulWidget)
function BenchmarkRoot:__init(options)
    self.scene = options.scene
    self.tick = options.tick
end

---@class BenchmarkState : State
---@field delta integer
---@overload fun(): self
local BenchmarkState = std.class.new('BenchmarkState', State)
function BenchmarkState:__init()
    State.__init(self)
    self.delta = 0
end
function BenchmarkState:build()
    local root = self.widget --[[@as BenchmarkRoot]]
    return scenes_mod.build(root.scene, root.tick + self.delta)
end
function BenchmarkRoot:create_state()
    return BenchmarkState()
end

---@param root Element
---@return integer
local function walk_elements(root)
    local count = 1
    for _, child in ipairs(root:element_children()) do
        count = count + walk_elements(child)
    end
    return count
end

---@param root RenderObject
---@param dirty boolean?
---@return integer
local function walk_render(root, dirty)
    if dirty then
        root:mark_needs_layout()
    end
    local count = 1
    for _, child in ipairs(root:children()) do
        count = count + walk_render(child, dirty)
    end
    return count
end

local report = { schema_version = 1, kind = 'framework-core', scene_version = 1,
    environment = stats_mod.environment(), iterations = iterations, warmup = warmup,
    viewport = { width = 1280, height = 720 }, scenarios = {} }
text_mod.set_default(ass_layout_mod.AssTextLayout())
local binding = binding_mod.WidgetsBinding.ensure_initialized()
for _, name in ipairs(scenes_mod.names) do
    local phases = {}
    local tree = binding:attach(BenchmarkRoot({ scene = name, tick = 0 }))
    local owner = tree.render_owner
    owner:set_viewport(Constraints.tight(1280, 720))
    owner:layout()
    local record = record_mod.RecordCanvas()
    local ass = ass_mod.AssCanvas()
    local replay = ass_mod.AssCanvas()
    local output_data = ''
    local elements, renders = 0, 0
    for index = 1, warmup + iterations do
        local measured = index > warmup
        local function sample(phase, operation)
            local start = now()
            operation()
            local elapsed = now() - start
            if measured then
                local values = phases[phase] or {}
                phases[phase] = values
                values[#values + 1] = elapsed
            end
        end
        ---@type Widget?
        local description
        sample('description', function()
            description = scenes_mod.build(name, index)
        end)
        ---@type WidgetTree?
        local mounted
        sample('mount', function()
            mounted = binding:attach(assert(description))
        end)
        sample('dispose', function()
            assert(mounted):dispose()
        end)
        local root = BenchmarkRoot({ scene = name, tick = index })
        sample('reconcile', function()
            tree:set_root_widget(root)
        end)
        local element = assert(tree.root_element) --[[@as StatefulElement]]
        local state = element.state --[[@as BenchmarkState]]
        state:set_state(function()
            state.delta = state.delta + 1
        end)
        sample('dirty_rebuild', function()
            tree.build_owner:rebuild_dirty()
        end)
        sample('finalize', function()
            tree.build_owner:finalize_tree()
        end)
        sample('element_traversal', function()
            elements = walk_elements(element)
        end)
        local render = assert(owner.root)
        sample('render_traversal', function()
            renders = walk_render(render)
        end)
        -- Mark every node outside timing so layout_dirty means full layout,
        -- rather than a root-only dirty flag with cached descendants.
        walk_render(render, true)
        sample('layout_dirty', function()
            owner:layout()
        end)
        sample('layout_clean', function()
            owner:layout()
        end)
        sample('regions_dirty', function()
            owner:region_snapshot()
        end)
        sample('regions_cached', function()
            owner:region_snapshot()
        end)
        sample('record_paint', function()
            record:reset()
            owner:mark_needs_paint()
            owner:paint(record)
        end)
        sample('ass_paint', function()
            ass:reset()
            owner:mark_needs_paint()
            owner:paint(ass)
        end)
        sample('payload', function()
            output_data = ass:text()
        end)
        -- Output check deliberately outside phase timings. Same operations,
        -- transforms and text must produce exactly the same event bytes.
        replay:reset()
        for _, op in ipairs(record.ops) do
            replay[op.name](replay, unpack(op, 1, op.n))
        end
        assert(replay:text() == output_data, 'Record/direct ASS mismatch: ' .. name)
    end
    local distributions = {}
    for phase, values in pairs(phases) do
        distributions[phase] = stats_mod.distribution(values)
    end
    report.scenarios[#report.scenarios + 1] = { name = name, phases = distributions,
        elements = elements, render_objects = renders, ass_events = #ass.events,
        ass_bytes = #output_data, output_data = output_data, output_equivalent = true }
    tree:dispose()
end
report.animation = animation_mod.run(iterations, warmup)
report.environment.mp_loaded = package.loaded.mp ~= nil
assert(not report.environment.mp_loaded, 'core benchmark loaded mp')
local file = assert(io.open(output, 'wb'))
file:write(json_mod.dumps(report))
file:close()
print('framework benchmark: ' .. #report.scenarios .. ' scenarios')
