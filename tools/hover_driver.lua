-- Shared behavior driver, using the production MpFrameClock/Scheduler/App pipeline.
---@namespace elxosc.tools.hover
---@using elxosc
local boundary_mod = require 'tools.hover_driver_boundary'
local scene_mod = require 'tools.hover_driver_scene'
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
    local trace = scene_mod.build(name, frames)
    local boundary = boundary_mod.install(mp, real_host == true)
    local app
    local report = {}
    local restore_hooks = function()
    end
    local stats = { frame = 0, paint = 0, present = 0, updates = 0, prepare = 0,
        dirty_build = 0, dirty_layout = 0, sections = {}, text_draws = {} }
    local actions, action_total = {}, 0
    local function action(kind, ...)
        action_total = action_total + 1
        actions[#actions + 1] = { kind = kind, values = { ... } }
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
            stats.text_draws[#stats.text_draws + 1] = {
                text = paragraph.text, position = { position.x, position.y }, anchor = text_paint and text_paint.anchor,
                size = { paragraph.size.width, paragraph.size.height }, lines = paragraph.lines,
                line_metrics = paragraph.line_metrics,
            }
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
        local pending_initial = boundary:resources().timers
        stats.frame, stats.paint, stats.present, stats.updates, stats.prepare = 0, 0, 0, 0, 0
        stats.dirty_build, stats.dirty_layout = 0, 0
        stats.text_draws = {}
        boundary.counts.requested, boundary.counts.emitted, boundary.counts.updates = 0, 0, 0
        actions = {}
        local initial_actions = action_total
        local outputs, state_batches, pointer_events = {}, 0, 0
        for _, step in ipairs(trace.steps) do
            stats.text_draws = {}
            boundary.time = step.time
            if step.environment then
                boundary.width, boundary.height, boundary.font = step.environment.width,
                    step.environment.height, step.environment.font
                app:_update_display()
            end
            if step.state then
                store:replace(store:get():copy(step.state))
                state_batches = state_batches + 1
            end
            if step.visible ~= nil then
                set_visible(app.binding.root_element, step.visible)
            end
            local dispatch = {}
            for _, point in ipairs(step.moves) do
                app:notify_activity(point.x, point.y, geometry.Rect.from_ltwh(0, 0, boundary.width, boundary.height))
                local position = geometry.Offset(point.x, point.y)
                local path, paths = {}, {}
                tree_paths(assert(owner_hooks.root), paths, 'root')
                for _, entry in ipairs(owner_hooks:pointer_path(position)) do
                    path[#path + 1] = { path = paths[entry.node], point = { entry.point.x, entry.point.y } }
                end
                local result = owner_hooks:dispatch_pointer_result(PointerEvent('move',
                    position, nil, { source = 'mouse', pointer_id = 1,
                        timestamp = step.time, buttons = {} }))
                dispatch[#dispatch + 1] = { result = result, hit_path = path }
                app:request_frame()
                pointer_events = pointer_events + 1
            end
            if options and options.fail_at == step.seq then
                error('injected hover driver failure')
            end
            boundary:emit()
            stats.sections = {}
            for section, enabled in pairs(boundary.sections) do
                stats.sections[section] = enabled
            end
            local current_actions = actions
            actions = {}
            outputs[#outputs + 1] = snapshot(app, current_actions, dispatch, stats)
        end
        report = { schema_version = 1, purpose = 'behavior validation; no performance timing',
            trace = trace, frames = outputs, pointer_events = pointer_events, state_batches = state_batches,
            counts = { requested = boundary.counts.requested, emitted = boundary.counts.emitted,
                callbacks = stats.frame, paint = stats.paint, present = stats.present, updates = stats.updates,
                prepare = stats.prepare, actions = action_total - initial_actions,
                dirty_build = stats.dirty_build, dirty_layout = stats.dirty_layout,
                estimate_requests = boundary.counts.estimate_requests,
                pending_initial = pending_initial, pending_end = boundary:resources().timers },
            runtime = jit.version, runtime_version_num = jit.version_num, jit_enabled = jit.status(),
            std_version = std.version, adapter = real_host and 'real-host' or 'lua',
            measurement = 'estimate-pair', native_submissions = real_host == true,
            native_raster = 'not observed', visible_frames = 'not observed' }
        -- Leave belongs to cleanup, outside the recorded scene/action window.
        owner_hooks:clear_hover()
        assert(not owner_hooks:has_pointer_capture())
    end)
    local cleaned, cleanup_error = true, nil
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
