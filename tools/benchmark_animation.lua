-- Paint isolation experiment using existing RecordCanvas, never a production cache.
local stats_mod = require 'tools.benchmark_support'
local scenes_mod = require 'tools.benchmark_scenes'
local binding_mod = require 'widget.widgets_binding'
local layout_mod = require 'widget.widgets.layout'
local constraints_mod = require 'layout.constraints'
local record_mod = require 'backends.record'
local ass_mod = require 'backends.ass_canvas'
local clock_mod = require 'scheduler.frame_clock'
local scheduler_mod = require 'scheduler.scheduler'
local controller_mod = require 'animation.controller'
local tween_mod = require 'animation.tween'
local geometry_mod = require 'foundation.geometry'
local std = require 'elxlibs.std'
local M = {}

---@class BenchmarkClock : FrameClock
---@field time number
---@overload fun(): self
local BenchmarkClock = std.class.new('BenchmarkClock', { clock_mod.FrameClock })
function BenchmarkClock:__init()
    self.time = 0
end
function BenchmarkClock:now()
    return self.time
end
function BenchmarkClock:request_frame()
end

---@param iterations integer
---@param warmup integer
---@return table[]
function M.run(iterations, warmup)
    local results = {}
    for _, name in ipairs(scenes_mod.names) do
        local clock = BenchmarkClock()
        local scheduler = scheduler_mod.Scheduler(clock)
        local tree = binding_mod.WidgetsBinding.ensure_initialized():attach(
            layout_mod.OffsetBox({ child = scenes_mod.build(name, 0) }))
        local owner = tree.render_owner
        owner:set_viewport(constraints_mod.Constraints.tight(1280, 720))
        owner:layout()
        local root = assert(owner.root) --[[@as RenderOffsetBox]]
        local cached = record_mod.RecordCanvas()
        owner:paint(cached)
        local canvas = ass_mod.AssCanvas()
        local replay = ass_mod.AssCanvas()
        local controller = controller_mod.AnimationController(scheduler, { duration = 1 })
        root:bind_offset_animation(controller, tween_mod.Tween(geometry_mod.Offset.zero(),
            geometry_mod.Offset(20, 0)) --[[@as Tween<Offset>]])
        controller:repeat_animation({ reverse = true })
        clock:_emit(0)
        local samples = { ticker = {}, full_paint = {}, record_replay = {} }
        local layout_frames, input_frames, paint_frames = 0, 0, 0
        local output = ''
        for index = 1, warmup + iterations do
            local generation = owner:region_snapshot().generation
            clock.time = clock.time + 1 / 240
            local start = stats_mod.now()
            clock:_emit(clock.time)
            local tick_seconds = stats_mod.now() - start
            local dirty_layout = owner:needs_layout()
            owner:layout()
            local dirty_paint = owner:needs_paint()
            start = stats_mod.now()
            canvas:reset()
            owner:paint(canvas)
            local paint_seconds = stats_mod.now() - start
            start = stats_mod.now()
            replay:reset()
            replay:save()
            replay:translate(root.offset.x, root.offset.y)
            for _, op in ipairs(cached.ops) do
                replay[op.name](replay, unpack(op, 1, op.n))
            end
            replay:restore()
            local replay_seconds = stats_mod.now() - start
            output = canvas:text()
            -- At the first zero-dt tick no paint is dirty; later frames must match.
            if dirty_paint then
                assert(output == replay:text(), 'animation isolation output mismatch: ' .. name)
            end
            if index > warmup then
                samples.ticker[#samples.ticker + 1] = tick_seconds
                samples.full_paint[#samples.full_paint + 1] = paint_seconds
                samples.record_replay[#samples.record_replay + 1] = replay_seconds
                layout_frames = layout_frames + (dirty_layout and 1 or 0)
                paint_frames = paint_frames + (dirty_paint and 1 or 0)
                input_frames = input_frames + (generation ~= owner:region_snapshot().generation and 1 or 0)
            end
        end
        assert(layout_frames == 0, 'paint-only animation caused layout')
        local distributions = {}
        for phase, values in pairs(samples) do
            distributions[phase] = stats_mod.distribution(values)
        end
        results[#results + 1] = { name = name, phases = distributions, layout_frames = layout_frames,
            paint_frames = paint_frames, input_invalidated_frames = input_frames, output_equivalent = true,
            cached_operations = #cached.ops, output_data = output }
        controller:dispose()
        scheduler:dispose()
        tree:dispose()
    end
    return results
end

return M
