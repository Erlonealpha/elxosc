-- Driver lifecycle and actual production-frame conservation, without performance assertions.
---@namespace test.hoverDriver
local F = require 'framework'
local mp_stub = require 'mp_stub'
local mp = mp_stub.install()
-- Other host tests install fresh mp tables while their required host modules retain
-- earlier tables. Load this fixture's five host adapters as one isolated set, then
-- restore the prior module cache below; production adapters are never patched.
local saved_host_modules = {}
local host_modules = { 'host.mpv_player_app', 'host.mpv_app', 'host.mpv_primitives',
    'host.mpv_input', 'host.mpv_actions' }
for _, name in ipairs(host_modules) do
    saved_host_modules[name] = package.loaded[name]
    package.loaded[name] = nil
end
local driver = require 'tools.hover_driver'
local scene = require 'tools.hover_driver_scene'
local boundary_mod = require 'tools.hover_driver_boundary'

F.section('shared direct hover driver')

F.test('playing runs production frames and actual timeline previews', function()
    local report = driver.run(mp, 'playing', 16, false)
    F.eq(report.pointer_events, 16, 'all pointers dispatched')
    F.eq(report.state_batches, 4, 'four state batches')
    F.eq(report.counts.callbacks, 16, 'actual Scheduler callbacks')
    F.eq(report.counts.emitted, 16, 'timer callbacks emitted')
    F.eq(report.counts.paint, 16, 'production paint executed')
    F.eq(report.counts.updates, 16, 'actual presenter updates')
    F.ok(#report.frames[16].tooltips > 0, 'actual Timeline Tooltip')
    F.ok(report.frames[16].tooltips[1].prepared ~= '', 'prepared final label')
    for _, count in pairs(report.cleanup) do
        F.eq(count, 0, 'resource released')
    end
end)

F.test('burst retains every pointer but coalesces into requested frames', function()
    local report = driver.run(mp, 'burst', 8, false)
    F.eq(report.pointer_events, 32, 'burst pointers conserved')
    F.eq(report.counts.callbacks, 8, 'burst frames coalesced')
    F.eq(#report.frames[8].dispatch, 4, 'four dispatches per checkpoint')
    F.ok(report.counts.prepare <= 8, 'prepare coalesced')
end)

F.test('stationary playback updates state without synthetic preview movement', function()
    local report = driver.run(mp, 'stationary', 16, false)
    F.eq(report.pointer_events, 1, 'only initial real movement')
    F.eq(report.state_batches, 4, 'playback continues')
    for index = 2, 16 do
        for _, action in ipairs(report.frames[index].actions) do
            F.ok(action.kind ~= 'thumb', 'no synthetic movement thumbnail')
        end
    end
end)

F.test('zero and clean traces do not force paint', function()
    local empty = driver.run(mp, 'clean', 0, false)
    F.eq(empty.counts.paint, 0, 'zero trace paints')
    F.eq(empty.pointer_events, 0, 'zero trace pointers')
    local clean = driver.run(mp, 'clean', 8, false)
    F.eq(clean.counts.paint, 0, 'clean trace paints')
end)

F.test('driver failure releases resources and restores mp slots for another run', function()
    local original_time = mp.get_time
    local original_overlay = mp.create_osd_overlay
    local ok, err = pcall(driver.run, mp, 'playing', 8, false, { fail_at = 3 })
    F.ok(not ok and tostring(err):find('injected hover driver failure', 1, true), 'failure propagated')
    F.eq(mp.get_time, original_time, 'clock slot restored')
    F.eq(mp.create_osd_overlay, original_overlay, 'overlay slot restored')
    F.ok(not tostring(err):find('unreleased', 1, true), 'failure path has no leaked resources')
    local next_run = driver.run(mp, 'paused-ms', 4, false)
    F.eq(next_run.counts.callbacks, 4, 'restart works after failure')
end)

F.test('environment and preview changes keep their own invalidation and cleanup', function()
    local environment = driver.run(mp, 'environment', 12, false)
    F.eq(environment.frames[3].viewport[1], 1440, 'new viewport in trace')
    F.eq(environment.frames[6].viewport[1], 1280, 'viewport restored')
    F.ok(environment.frames[6].text_generation > environment.frames[1].text_generation,
        'text environment replaced')
    local preview = driver.run(mp, 'preview', 16, false)
    -- State publishes before this frame's build. The old callback may run on the
    -- transition dispatch, then production build clears it; later moves are blocked.
    for index = 5, 7 do
        for _, action in ipairs(preview.frames[index].actions) do
            F.ok(action.kind ~= 'thumb', 'unavailable capability blocks previews')
        end
    end
    local transition = assert(preview.frames[4].actions) --[[@as table[] ]]
    F.eq(transition[#transition].kind, 'clear', 'capability transition clears old preview')
    F.ok(#preview.frames[10].actions > 0, 'leave produces cleanup action')
    F.eq(#preview.frames[12].tooltips, 0, 'hidden tooltip cleared')
    F.ok(#preview.frames[16].tooltips > 0, 'real move restores visible tooltip')
    F.ok(preview.cleanup_state.root_detached, 'root detached at shutdown')
end)

F.test('boundary rejects nested runs and cancels pending timers', function()
    local boundary = boundary_mod.install(mp, false)
    local ok = pcall(boundary_mod.install, mp, false)
    F.ok(not ok, 'nested boundary rejected')
    local timer = mp.add_timeout(0, function() error('cancelled timer fired') end)
    timer:kill()
    F.ok(not boundary:emit(), 'cancelled timer not emitted')
    boundary.restore()
    F.ok(not pcall(scene.build, 'unknown', 4), 'unknown scene rejected')
    F.ok(not pcall(scene.build, 'playing', 513), 'unbounded scene rejected')
end)

F.test('explicit style trace changes painted colors with the same pointer and time sequence', function()
    local plain = scene.build('paused-ms', 8)
    local changed = scene.build('paused-ms', 8, { style_updates = true })
    for index = 1, 8 do
        F.eq(changed.steps[index].time, plain.steps[index].time, 'logical clock unchanged')
        F.eq(changed.steps[index].moves[1].x, plain.steps[index].moves[1].x, 'pointer unchanged')
    end
    F.eq(changed.steps[4].style_variant, 2, 'first explicit palette')
    F.eq(changed.steps[8].style_variant, 1, 'original palette restored')
    local report = driver.run(mp, 'paused-ms', 8, false, { trace_options = { style_updates = true } })
    F.eq(report.pointer_events, 8, 'all pointer events retained')
    F.eq(report.counts.callbacks, 8, 'normal production frames')
    F.ok(report.frames[4].ass:find('&HD5E59F&', 1, true) ~= nil, 'new time color reaches ASS')
    for _, count in pairs(report.cleanup) do
        F.eq(count, 0, 'style trace resources released')
    end
    F.ok(not pcall(scene.build, 'paused-ms', 8, { style_updates = 'yes' }), 'invalid variant rejected')
end)

for _, name in ipairs(host_modules) do
    package.loaded[name] = saved_host_modules[name]
end
