-- Scoped hover-cost probe; run from the repository root with LuaJIT.
-- This isolates Lua work with the mp stub; it does not measure OS input latency,
-- timer wait, libass rasterization or the external thumbfast process.

local support = require 'test.support'
support.bootstrap('test')

local mp_stub = require 'mp_stub'
mp_stub.install()
mp_stub.reset()
local app_mod = require 'host.mpv_app'
local main_mod = require 'main_layout'
local player_mod = require 'widget.player_context'
local actions_mod = require 'widget.actions'
local element_mod = require 'widget.element'
local ffi = require 'ffi'
local geometry_mod = require 'foundation.geometry'
local Offset = geometry_mod.Offset

local now = os.clock
if ffi.os == 'Windows' then
    ffi.cdef [[
        int QueryPerformanceCounter(int64_t *value);
        int QueryPerformanceFrequency(int64_t *value);
    ]]
    local frequency = ffi.new('int64_t[1]') --[[@as integer[] ]]
    local counter = ffi.new('int64_t[1]') --[[@as integer[] ]]
    ffi.C.QueryPerformanceFrequency(frequency)
    local divisor = assert(tonumber(frequency[0]))
    now = function()
        ffi.C.QueryPerformanceCounter(counter)
        return assert(tonumber(counter[0])) / divisor
    end
end

local rebuilds = 0
for _, name in ipairs({ 'StatelessElement', 'StatefulElement', 'ProxyElement',
    'ParentDataElement', 'RenderObjectElement', 'SingleChildRenderObjectElement',
    'MultiChildRenderObjectElement' }) do
    local class = element_mod[name]
    local original = class.rebuild
    -- Runtime class instrumentation; std.class's callable annotation has no self parameter.
    ---@diagnostic disable-next-line: redundant-parameter
    class.rebuild = function(self)
        rebuilds = rebuilds + 1
        return original(self)
    end
end

local function noop()
end
local chapters = {}
for index = 0, 19 do
    chapters[#chapters + 1] = { time = index * 30, title = 'Chapter ' .. index }
end
local actions = actions_mod.HostActions({
    seek_to = noop, seek = noop, play_pause = noop, playlist_prev = noop,
    playlist_next = noop, chapter_prev = noop, chapter_next = noop,
    set_volume = noop, toggle_mute = noop, toggle_fullscreen = noop,
    toggle_ontop = noop, set_track = noop, minimize = noop, close = noop,
    thumbfast_request = noop, thumbfast_clear = noop,
})
local app = app_mod.App(main_mod.build_app(), {
    actions = actions,
    player_store = player_mod.PlayerStore({
        duration = 600, time_pos = 100, percent_pos = 100 / 6, volume = 72,
        volume_max = 100, chapter_list = chapters, chapter = 3,
        track_list = { { type = 'audio', id = 1 }, { type = 'sub', id = 1 } },
        capabilities = { thumbfast = { status = 'available', detail = '320x180' } },
    }),
})
app:render()

local iterations = tonumber(arg[1]) or 2000
local warmup = 200
local samples = {}
local sums = { activity = 0, dispatch = 0, build = 0, layout = 0, regions = 0, paint = 0, present = 0 }
local layout_frames, input_frames, build_count = 0, 0, 0

for index = 1, warmup + iterations do
    local x, y = 100 + index % 1000, 570
    local generation = app.owner:region_snapshot().generation
    local previous_rebuilds = rebuilds
    local start = now()
    local t = start
    app:notify_activity(x, y, app:_input_viewport())
    local after_activity = now()
    app.owner:dispatch_pointer('move', Offset(x, y))
    local after_dispatch = now()
    app.binding:flush_build()
    local after_build = now()
    local layout_dirty = app.owner:needs_layout()
    app.owner:layout()
    local after_layout = now()
    app.input:update_regions()
    local after_regions = now()
    app.canvas:reset()
    app.owner:paint(app.canvas)
    local after_paint = now()
    app.presenter:present(app.canvas, app.display.width, app.display.height)
    local finish = now()
    if index > warmup then
        sums.activity = sums.activity + after_activity - t
        sums.dispatch = sums.dispatch + after_dispatch - after_activity
        sums.build = sums.build + after_build - after_dispatch
        sums.layout = sums.layout + after_layout - after_build
        sums.regions = sums.regions + after_regions - after_layout
        sums.paint = sums.paint + after_paint - after_regions
        sums.present = sums.present + finish - after_paint
        build_count = build_count + rebuilds - previous_rebuilds
        layout_frames = layout_frames + (layout_dirty and 1 or 0)
        input_frames = input_frames + (generation ~= app.owner:region_snapshot().generation and 1 or 0)
        samples[#samples + 1] = (finish - start) * 1000
    end
end

table.sort(samples)
print(string.format('runtime=%s platform=%s/%s viewport=1280x720 scale=1.5 warmup=%d samples=%d',
    jit.version, ffi.os, ffi.arch, warmup, iterations))
for _, name in ipairs({ 'activity', 'dispatch', 'build', 'layout', 'regions', 'paint', 'present' }) do
    print(string.format('%s_mean_ms=%.4f', name, sums[name] * 1000 / iterations))
end
print(string.format('total_p50_ms=%.4f total_p95_ms=%.4f total_max_ms=%.4f',
    samples[math.ceil(iterations * 0.5)], samples[math.ceil(iterations * 0.95)], samples[iterations]))
print(string.format('element_rebuild_calls=%d layout_frames=%d input_invalidated_frames=%d ass_bytes=%d',
    build_count, layout_frames, input_frames, #app.canvas:text()))
app:shutdown()
