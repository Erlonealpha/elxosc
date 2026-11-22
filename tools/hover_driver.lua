-- Shared behavior driver, using the production MpFrameClock/Scheduler/App pipeline.
---@namespace elxosc.tools.hover
---@using elxosc
local boundary_mod = require 'tools.hover_driver_boundary'
local scene_mod = require 'tools.hover_driver_scene'
local profiler_mod = require 'tools.hover_profiler'
local timing = require 'tools.benchmark_support'
local std = require 'elxlibs.std'
local json = require 'elxlibs.json'
local geometry = require 'src.foundation.geometry'
local PointerEvent = require('src.foundation.pointer_event').PointerEvent
local PlayerStore = require('player.src.context').PlayerStore
local HostActions = require('player.src.actions').HostActions
local PlayerThemeData = require('player.src.theme').PlayerThemeData
local composition = require 'player.src.composition'
local Tooltip = require('src.widgets.tooltip').Tooltip
local AutoHide = require('player.src.auto_hide').AutoHide
local M = {}

local function rect_values(rect)
    return { rect.left, rect.top, rect.right, rect.bottom }
end

local function tree_paths(root, paths, prefix)
    paths[root] = prefix .. ':' .. root.__class.__name
    for index, child in ipairs(root:children()) do
        tree_paths(child, paths, prefix .. '/' .. index)
    end
end

local function tooltips(element, out)
    if std.isinstance(element.widget, Tooltip) then
        local state = element.state
        if state.hovered and state.hover_point then
            local paragraph = state._paragraph
            out[#out + 1] = { text = state.hover_label, point = { state.hover_point.x, state.hover_point.y },
                prepared = paragraph and paragraph.text or '', width = paragraph and paragraph.size.width or 0 }
        end
    end
    for _, child in ipairs(element:element_children()) do
        tooltips(child, out)
    end
end

local function set_visible(element, visible)
    if std.isinstance(element.widget, AutoHide) then
        element.widget.controller:set_visible(visible)
    end
    for _, child in ipairs(element:element_children()) do
        set_visible(child, visible)
    end
end

local function root_with_scale(root, scale)
    local app_options, main_options = {}, {}
    for key, value in pairs(rawget(root, '__dict')) do
        app_options[key] = value
    end
    for key, value in pairs(rawget(root.main, '__dict')) do
        main_options[key] = value
    end
    main_options.scale = scale
    app_options.main = root.main.__class(main_options)
    return root.__class(app_options)
end

local function snapshot(app, actions, dispatch, stats)
    local paths, regions, labels = {}, {}, {}
    tree_paths(assert(app.owner.root), paths, 'root')
    local region_snapshot = app.owner:region_snapshot()
    for _, region in ipairs(region_snapshot:regions()) do
        regions[#regions + 1] = { path = paths[region.node], rect = rect_values(region.rect),
            down = region.down, wheel = region.wheel }
    end
    tooltips(app.binding.root_element, labels)
    return { ass = app.canvas:text(), regions = regions, tooltips = labels, actions = actions,
        dispatch = dispatch, input_generation = region_snapshot.generation,
        text_generation = app.text_layout_generation, capture = app.owner:has_pointer_capture(),
        frame = stats.frame, paint = stats.paint, present = stats.present, updates = stats.updates,
        dirty_build = stats.dirty_build, dirty_layout = stats.dirty_layout, prepare = stats.prepare,
        sections = stats.sections, text_draws = stats.text_draws,
        player_snapshot = app.player_store:get():to_table(),
        viewport = { app.display.width, app.display.height } }
end

---@param mp table
---@param name string
---@param frames integer
---@param real_host boolean?
---@param options table? injected failures are only for driver lifecycle tests
---@return table
function M.run(mp, name, frames, real_host, options)
    options = options or {}
    local mode = options.mode or 'validation'
    local allowed = { validation = true, baseline = true, phase = true, ['class-count'] = true,
        ['table-sites'] = true, ['sample-function'] = true, ['sample-line'] = true, gc = true, ['gc-off'] = true }
    if not allowed[mode] then
        error('unknown hover measurement mode')
    end
    local validation = mode == 'validation'
    local profiler = profiler_mod.new(mode)
    local scene_options = options.trace_options or {}
    local trace = scene_mod.build(name, frames, scene_options)
    local boundary = boundary_mod.install(mp, real_host == true, options)
    local app
    local report = {}
    local restore_hooks = function()
    end
    local stats = { frame = 0, paint = 0, present = 0, updates = 0, prepare = 0,
        dirty_build = 0, dirty_layout = 0, sections = {}, text_draws = {} }
    local actions, action_total = {}, 0
    local function action(kind, ...)
        action_total = action_total + 1
        if validation then
            actions[#actions + 1] = { kind = kind, values = { ... } }
        end
    end
    local ok, err = pcall(function()
        -- Load only after the scoped mp boundary is installed.
        local PlayerHostApp = require('host.mpv_player_app').PlayerHostApp
        local chapters = {}
        for index = 0, 19 do
            chapters[#chapters + 1] = { time = index * 30, title = 'Chapter ' .. index }
        end
        local store = PlayerStore({ duration = 600, time_pos = 100, percent_pos = 100 / 6,
            pause = not trace.playing, idle_active = false, volume = 72, volume_max = 100,
            media_title = 'Shared direct hover', filename = 'generated.mp4', file_size = 123456789,
            chapter_list = chapters, chapter = 3, track_list = { { type = 'audio', id = 1 }, { type = 'sub', id = 1 } },
            cache_state = { ['seekable-ranges'] = { { start = 0, ['end'] = 150 } } },
            capabilities = { thumbfast = { status = 'available', detail = '320x180' } } })
        local function noop()
        end
        local host_actions = HostActions({ seek_to = function(value) action('seek', value) end,
            seek = noop, play_pause = noop, playlist_prev = noop, playlist_next = noop,
            chapter_prev = noop, chapter_next = noop, set_volume = noop, toggle_mute = noop,
            toggle_fullscreen = noop, toggle_ontop = noop, set_track = noop, minimize = noop, close = noop,
            thumbfast_request = function(...) action('thumb', ...) end,
            thumbfast_clear = function() action('clear') end })
        app = PlayerHostApp(composition.build_app(), { player_store = store, actions = host_actions,
            player_theme = PlayerThemeData({ time_ms = trace.milliseconds }), delay = 1 / 240 })
        local style_themes
        if scene_options.style_updates then
            local Color = require('src.foundation.color').Color
            style_themes = { app.player_theme, PlayerThemeData({ time_ms = trace.milliseconds,
                title_color = Color.hex('#F4B8D8'), time_color = Color.hex('#9FE5D5'),
                description_color = Color.hex('#AED1FF') }) }
        end
        local app_hooks = app --[[@as table]]
        local render = app_hooks.render
        app_hooks.render = function(instance)
            if instance.binding.build_owner:has_dirty() then
                stats.dirty_build = stats.dirty_build + 1
            end
            return render(instance)
        end
        -- Instance-only validation hooks; no class methods or runtime globals are changed.
        local owner_hooks = app.owner --[[@as table]]
        local paint = owner_hooks.paint
        owner_hooks.paint = function(owner, canvas)
            stats.paint = stats.paint + 1
            return paint(owner, canvas)
        end
        local present = app.presenter.present
        app.presenter.present = function(presenter, ...)
            stats.present = stats.present + 1
            local submitted = present(presenter, ...)
            if submitted then
                stats.updates = stats.updates + 1
            end
            return submitted
        end
        local prepare = owner_hooks.flush_prepare
        owner_hooks.flush_prepare = function(owner)
            if #owner._prepare_order > 0 then
                stats.prepare = stats.prepare + 1
            end
            return prepare(owner)
        end
        local layout = owner_hooks.layout
        owner_hooks.layout = function(owner)
            if owner:needs_layout() then
                stats.dirty_layout = stats.dirty_layout + 1
            end
            return layout(owner)
        end
        local canvas_hooks = app.canvas --[[@as table]]
        local draw_text = canvas_hooks.draw_text
        canvas_hooks.draw_text = function(canvas, paragraph, position, text_paint)
            if validation then
                stats.text_draws[#stats.text_draws + 1] = {
                    text = paragraph.text, position = { position.x, position.y }, anchor = text_paint and text_paint.anchor,
                    size = { paragraph.size.width, paragraph.size.height }, lines = paragraph.lines,
                    line_metrics = paragraph.line_metrics,
                }
            end
            return draw_text(canvas, paragraph, position, text_paint)
        end
        restore_hooks = function()
            owner_hooks.paint = nil
            owner_hooks.flush_prepare = nil
            owner_hooks.layout = nil
            app.presenter.present = nil
            canvas_hooks.draw_text = nil
            app_hooks.render = nil
        end
        local frame_callback = function()
            stats.frame = stats.frame + 1
        end
        app.scheduler:add_persistent(frame_callback)
        assert(boundary:emit(), 'initial scheduled production frame missing')
        if mode == 'phase' or mode == 'class-count' then
            profiler:wrap(app_hooks, 'notify_activity', 'activity')
            profiler:wrap(app_hooks, 'render', 'frame')
            profiler:wrap(app.binding --[[@as table]], 'flush_build', 'build')
            profiler:wrap(owner_hooks, 'layout', 'layout')
            profiler:wrap(owner_hooks, 'flush_prepare', 'prepare')
            profiler:wrap(app.input --[[@as table]], 'update_regions', 'regions')
            profiler:wrap(app.input --[[@as table]], '_sync_navigation', 'navigation')
            profiler:wrap(owner_hooks, 'dispatch_pointer_result', 'dispatch')
            profiler:wrap(owner_hooks, 'paint', 'paint')
            profiler:wrap(app.presenter --[[@as table]], 'present', 'present')
            profiler:wrap(store --[[@as table]], 'replace', 'store_notify')
            profiler:wrap(app.text_layout --[[@as table]], 'layout', 'text_layout')
        end
        if mode == 'class-count' then
            local dataclass = require 'elxlibs.dataclass'
            for _, module in ipairs({ 'src.foundation.geometry', 'src.foundation.transform',
                'src.layout.constraints', 'src.foundation.color', 'src.painting.paint' }) do
                for _, cls in pairs(require(module)) do
                    if dataclass.isclass(cls) then
                        profiler:track_dataclass(cls)
                    end
                end
            end
        end
        local function perform_step(step, offset)
            boundary.time = offset + step.time
            if step.style_variant then
                app.player_theme = assert(style_themes)[step.style_variant]
                app:set_root_widget(app.root_widget)
            end
            if step.environment then
                boundary.width, boundary.height, boundary.font = step.environment.width,
                    step.environment.height, step.environment.font
                app:_update_display()
                if step.environment.scale then
                    app:set_root_widget(root_with_scale(app.root_widget, step.environment.scale))
                end
            end
            if step.state then
                profiler.stage = 'state'
                profiler.batch_id = profiler.batch_id + 1
                local scope = profiler:enter('state')
                store:replace(store:get():copy(step.state))
                profiler:leave(scope)
            end
            if step.visible ~= nil then
                set_visible(app.binding.root_element, step.visible)
            end
            local dispatch = validation and {} or nil
            for _, point in ipairs(step.moves) do
                profiler.stage = 'activity'
                app:notify_activity(point.x, point.y, geometry.Rect.from_ltwh(0, 0, boundary.width, boundary.height))
                local position = geometry.Offset(point.x, point.y)
                local path
                if validation then
                    path = {}
                    local paths = {}
                    tree_paths(assert(owner_hooks.root), paths, 'root')
                    for _, entry in ipairs(owner_hooks:pointer_path(position)) do
                        path[#path + 1] = { path = paths[entry.node], point = { entry.point.x, entry.point.y } }
                    end
                end
                profiler.stage = 'dispatch'
                local result = owner_hooks:dispatch_pointer_result(PointerEvent('move', position, nil,
                    { source = 'mouse', pointer_id = 1, timestamp = boundary.time, buttons = {} }))
                if validation then
                    local results = assert(dispatch)
                    results[#results + 1] = { result = result, hit_path = path }
                end
                app:request_frame()
            end
            if options.fail_at == step.seq then
                error('injected hover driver failure')
            end
            profiler.stage = 'frame'
            boundary:emit()
            return dispatch
        end
        local warmup = options.warmup or 0
        assert(warmup >= 0 and warmup <= 128 and warmup == math.floor(warmup), 'warmup out of range')
        local warmup_trace = scene_mod.build(name, warmup, scene_options)
        for _, step in ipairs(warmup_trace.steps) do
            perform_step(step, 0)
        end
        local offset = warmup_trace.steps[warmup] and warmup_trace.steps[warmup].time or 0
        local pending_initial = boundary:resources().timers
        stats.frame, stats.paint, stats.present, stats.updates, stats.prepare = 0, 0, 0, 0, 0
        stats.dirty_build, stats.dirty_layout = 0, 0
        stats.text_draws = {}
        boundary.counts.requested, boundary.counts.emitted, boundary.counts.updates = 0, 0, 0
        actions = {}
        local initial_actions = action_total
        local outputs, state_batches, pointer_events = {}, 0, 0
        local elapsed_values = {}
        local heap_start = collectgarbage('count')
        if mode == 'gc' then
            collectgarbage('collect')
            heap_start = collectgarbage('count')
        elseif mode == 'gc-off' then
            collectgarbage('stop')
        end
        profiler:start()
        if options.sites then
            options.sites.active = true
        end
        local service_total = 0
        for _, step in ipairs(trace.steps) do
            if validation then
                stats.text_draws = {}
            end
            profiler.frame_id = step.seq
            local started = timing.now()
            local scope = profiler:enter('service')
            local dispatch = perform_step(step, offset)
            profiler:leave(scope)
            local elapsed = timing.now() - started
            service_total = service_total + elapsed
            elapsed_values[#elapsed_values + 1] = elapsed
            if step.state then
                state_batches = state_batches + 1
            end
            pointer_events = pointer_events + #step.moves
            if validation then
                stats.sections = {}
                for section, enabled in pairs(boundary.sections) do
                    stats.sections[section] = enabled
                end
                local current_actions = actions
                actions = {}
                outputs[#outputs + 1] = snapshot(app, current_actions, dispatch, stats)
            end
            if options.paced then
                profiler.active = false
                coroutine.yield()
                if options.checkpoint and (step.seq == 1 or step.seq == math.ceil(frames / 2) or step.seq == frames) then
                    options.checkpoint(canvas_hooks:text(), boundary.width, boundary.height, step.seq, boundary.original)
                end
                profiler.active = true
            end
        end
        if options.sites then
            options.sites.active = false
            profiler.sites = options.sites.counts
            profiler.site_coverage = options.sites.coverage
        end
        profiler:stop()
        local heap_end = collectgarbage('count')
        if mode == 'gc-off' then
            collectgarbage('restart')
        end
        collectgarbage('collect')
        collectgarbage('collect')
        local heap_retained = collectgarbage('count')
        if not validation then
            outputs[1] = snapshot(app, {}, {}, stats)
        end
        if options.text_mode == 'replay' then
            assert(not boundary.replay_error, boundary.replay_error)
            assert(boundary.replay_index == #options.corpus, 'native replay corpus has unused requests')
        end
        report = { schema_version = 1, purpose = validation and 'behavior validation' or 'instrumented service measurement',
            trace = trace, frames = outputs, pointer_events = pointer_events, state_batches = state_batches,
            mode = mode, warmup = warmup, profiling = profiler:report(), service = profiler_mod.distribution(elapsed_values),
            service_total_seconds = service_total, heap = { start_kib = heap_start, end_kib = heap_end,
                retained_kib = heap_retained, gc_control = mode },
            native_requests = boundary.native_requests, replay_requests = boundary.replay_index,
            native_seconds = boundary.native_seconds,
            counts = { requested = boundary.counts.requested, emitted = boundary.counts.emitted,
                callbacks = stats.frame, paint = stats.paint, present = stats.present, updates = stats.updates,
                prepare = stats.prepare, actions = action_total - initial_actions,
                dirty_build = stats.dirty_build, dirty_layout = stats.dirty_layout,
                estimate_requests = boundary.counts.estimate_requests,
                pending_initial = pending_initial, pending_end = boundary:resources().timers },
            runtime = jit.version, runtime_version_num = jit.version_num, jit_enabled = jit.status(),
            std_version = std.version, adapter = real_host and 'real-host' or 'lua',
            measurement = options.text_mode or 'estimate', native_submissions = real_host == true,
            native_raster = 'not observed', visible_frames = 'not observed' }
        -- Leave belongs to cleanup, outside the recorded scene/action window.
        owner_hooks:clear_hover()
        assert(not owner_hooks:has_pointer_capture())
    end)
    local cleaned, cleanup_error = true, nil
    if options.sites then
        options.sites.active = false
        options.sites:restore()
    end
    profiler:stop()
    if mode == 'gc-off' then
        collectgarbage('restart')
    end
    if app then
        restore_hooks()
        cleaned, cleanup_error = pcall(app.shutdown, app)
    end
    local resources = boundary:resources()
    report.cleanup_actions = actions
    report.cleanup_state = app and { root_detached = app.owner.root == nil,
        clock_handler_removed = not app.clock:has_handler(), scheduled = app.scheduler:is_frame_scheduled() }
    boundary.restore()
    if not ok then
        local leaks = ''
        for kind, remaining in pairs(resources) do
            if remaining ~= 0 then
                leaks = leaks .. '; unreleased ' .. kind .. ': ' .. remaining
            end
        end
        error(tostring(err) .. (cleaned and '' or '; cleanup: ' .. tostring(cleanup_error)) .. leaks, 0)
    end
    assert(cleaned, cleanup_error)
    for kind, remaining in pairs(resources) do
        assert(remaining == 0, 'hover resource not released: ' .. kind)
    end
    report.cleanup = resources
    return report
end

function M.write(path, report)
    local file = assert(io.open(path, 'wb'))
    file:write(json.dumps(report), '\n')
    file:close()
end

return M
