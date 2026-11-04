-- P2 ModernX player slice: fixed progress bar, player snapshot mapping and
-- explicit host action boundaries.

---@diagnostic disable: undefined-field, inject-field, need-check-nil, generic-constraint-mismatch, preferred-local-alias, unused

local F = require 'framework'
local std = require 'elxlibs.std'
local mp_stub = require 'mp_stub'
mp_stub.install()

local geometry = require 'foundation.geometry'
local color_mod = require 'foundation.color'
local pointer_event = require 'foundation.pointer_event'
local constraints_mod = require 'layout.constraints'
local render_owner_mod = require 'render.render_owner'
local progress_mod = require 'render.progress_bar'
local record_mod = require 'backends.record'
local actions_mod = require 'widget.actions'
local player_context = require 'widget.player_context'
local mpv_player_context = require 'host.mpv_player_context'
local mpv_actions = require 'host.mpv_actions'
local widget_api = require 'widget'
local player_api = require 'widget.player'
local progress_widget = require 'widget.player.progress_bar'

local Offset = geometry.Offset
local Size = geometry.Size
local Color = color_mod.Color
local Constraints = constraints_mod.Constraints
local RenderOwner = render_owner_mod.RenderOwner
local RenderProgressBar = progress_mod.RenderProgressBar
local RecordCanvas = record_mod.RecordCanvas
local HostActions = actions_mod.HostActions
local PlayerStore = player_context.PlayerStore
local MpPlayerContext = mpv_player_context.MpPlayerContext
local fake = mp_stub.fake
local PointerEvent = pointer_event.PointerEvent

local function layout_bar(bar)
    local owner = RenderOwner(bar)
    owner:set_viewport(Constraints.tight(200, 20))
    owner:layout()
    return owner
end

F.section('modernx player: progress and input')

F.test('player aggregate preserves direct ProgressBar identity', function()
    F.eq(player_api.ProgressBar, progress_widget.ProgressBar,
        'player aggregate/direct ProgressBar identity')
    F.eq(widget_api.ProgressBar, progress_widget.ProgressBar,
        'widget aggregate/player ProgressBar identity')
end)

F.test('progress bar paints track, buffer, progress and handle', function()
    local bar = RenderProgressBar({ progress = 0.25, buffered = 0.6 })
    local owner = layout_bar(bar)
    local canvas = RecordCanvas()
    owner:paint(canvas)
    F.eq(canvas:count('draw_rrect'), 4, 'four static progress primitives')
    F.eq(#owner:pointer_regions(), 0, 'read-only progress bar does not claim input')
end)

F.test('progress updates are paint-only and seek capture keeps the last fraction', function()
    local phases = {}
    local fractions = {}
    local bar = RenderProgressBar({
        progress = 0.1,
        on_seek = function(fraction, phase)
            phases[#phases + 1] = phase
            fractions[#fractions + 1] = fraction
        end,
    })
    local owner = layout_bar(bar)
    owner:paint(RecordCanvas())
    owner._needs_layout = false
    owner._needs_paint = false

    bar:set_progress(0.4)
    F.ok(not owner:needs_layout(), 'progress setter does not relayout')
    F.ok(owner:needs_paint(), 'progress setter marks paint')
    F.eq(#owner:pointer_regions(), 1, 'seek bar claims one input region')

    owner:dispatch_pointer('down', Offset(50, 10), 'left')
    owner:dispatch_pointer('move', Offset(150, 10))
    owner:dispatch_pointer('up', Offset(500, 10), 'left')
    F.eq(phases[1], 'start', 'drag starts')
    F.eq(phases[2], 'update', 'drag updates')
    F.eq(phases[3], 'end', 'drag ends after leaving the bar')
    F.close(fractions[1], 0.25, 'start fraction')
    F.close(fractions[2], 0.75, 'update fraction')
    F.close(fractions[3], 0.75, 'last fraction is used on outside release')
    F.ok(not bar.dragging, 'capture state is released')
end)

F.test('progress bar rejects invalid fractions at the render boundary', function()
    F.raises(function()
        RenderProgressBar({ progress = 1.1 })
    end, 'between 0 and 1', 'invalid initial progress')
    local bar = RenderProgressBar()
    F.raises(function()
        bar:set_buffered(-0.1)
    end, 'between 0 and 1', 'invalid buffered update')
end)

F.test('progress hover, wheel, right-click and shift seek stay on one input region', function()
    local phases = {}
    local modes = {}
    local chapter_fraction
    local wheel_delta
    local bar = RenderProgressBar({
        progress = 0.25,
        hover_expand = 6,
        hover_handle_size = 1,
        on_seek = function(fraction, phase, mode)
            phases[#phases + 1] = phase
            modes[#modes + 1] = mode
        end,
        on_context_seek = function(fraction)
            chapter_fraction = fraction
        end,
        on_wheel = function(delta)
            wheel_delta = delta
        end,
    })
    local owner = layout_bar(bar)
    owner:dispatch_pointer('move', Offset(50, 10))
    F.ok(bar.hovered, 'progress bar responds to pointer enter')
    F.eq(owner:pointer_regions()[1].rect, geometry.Rect(-6, -6, 206, 26),
        'hover hitbox expands without changing layout')
    owner:dispatch_pointer('wheel', Offset(50, 10), 1)
    F.eq(wheel_delta, 1, 'wheel reaches the slider')

    owner:dispatch_pointer_result(PointerEvent({
        type = 'down', point = Offset(100, 10), button = 'right', data = 'right',
    }))
    F.close(chapter_fraction or -1, 0.5, 'right click reports chapter fraction')

    owner:dispatch_pointer_result(PointerEvent({
        type = 'down', point = Offset(25, 10), button = 'left', data = 'left',
        modifiers = { shift = true },
    }))
    owner:dispatch_pointer('move', Offset(75, 10))
    owner:dispatch_pointer_result(PointerEvent({
        type = 'up', point = Offset(75, 10), button = 'left', data = 'left',
    }))
    F.eq(phases[1], 'start', 'shift drag starts')
    F.eq(modes[1], 'exact', 'shift drag selects exact seek')
    F.eq(phases[#phases], 'end', 'shift drag ends')

    owner:dispatch_pointer('down', Offset(10, 10), 'left')
    owner:dispatch_pointer('cancel')
    F.eq(phases[#phases], 'cancel', 'cancel resets the seek sequence')
    F.ok(not bar.dragging, 'cancel releases slider state')
end)

F.test('gap chapter markers cut the track instead of adding marker shapes', function()
    local bar = RenderProgressBar({
        progress = 0.75,
        buffered = 0.9,
        marker_style = 'gap',
        markers = {
            { fraction = 0 },
            { fraction = 0.5 },
            { fraction = 1 },
        },
    })
    local owner = layout_bar(bar)
    local canvas = RecordCanvas()
    owner:paint(canvas)
    F.eq(canvas:count('draw_path'), 0, 'gap style has no marker path')
    F.ok(canvas:count('draw_rrect') > 4, 'gap style splits track and progress segments')
end)

F.test('progress ranges preserve optional SponsorBlock colors', function()
    local range_color = Color.hex('#6BCB77')
    local bar = RenderProgressBar({
        ranges = { { start = 0.1, ['end'] = 0.2, color = range_color } },
    })
    local owner = layout_bar(bar)
    local canvas = RecordCanvas()
    owner:paint(canvas)
    for _, operation in ipairs(canvas.ops) do
        if operation.name == 'draw_rrect' and operation[3].color == range_color then
            F.ok(true, 'range paint preserves its category color')
            return
        end
    end
    F.ok(false, 'range paint preserves its category color')
end)

F.test('progress range expansion matches the ModernX cache gap', function()
    local bar = RenderProgressBar({
        range_expand = 7,
        ranges = { { start = 0.5, ['end'] = 0.5 } },
    })
    F.eq(bar.range_expand, 7, 'range expansion is retained')
    local owner = layout_bar(bar)
    local canvas = RecordCanvas()
    owner:paint(canvas)
    local found_expanded_range = false
    for _, operation in ipairs(canvas.ops) do
        if operation.name == 'draw_rrect'
            and operation[1].left == 93 and operation[1].right == 107 then
            found_expanded_range = true
        end
    end
    F.ok(found_expanded_range, 'cache ranges expand around their endpoints')
end)

F.test('seekbar configuration selects the default keyframe or exact mode', function()
    local mode
    local bar = RenderProgressBar({
        seek_mode = 'exact',
        on_seek = function(_, phase, selected_mode)
            if phase == 'start' then
                mode = selected_mode
            end
        end,
    })
    local owner = layout_bar(bar)
    owner:dispatch_pointer('down', Offset(20, 10), 'left')
    F.eq(mode, 'exact', 'configured exact mode is used without shift')
    owner:dispatch_pointer('cancel')
end)

F.section('modernx player: snapshot and actions')

F.test('default mpv properties map to immutable player fields', function()
    mp_stub.reset()
    local store = PlayerStore()
    local context = MpPlayerContext(store)
    local subscriptions = context:observe_default_properties()
    F.eq(#subscriptions, 30, 'default property set is explicit')
    local by_name = {}
    for _, event in ipairs(fake.events) do
        by_name[event.name] = event.cb
    end
    by_name['media-title']('media-title', 'Episode 7')
    by_name['time-pos']('time-pos', 12.5)
    by_name['duration']('duration', 100)
    by_name['percent-pos']('percent-pos', 12.5)
    by_name['pause']('pause', true)
    by_name['fullscreen']('fullscreen', true)
    by_name['volume']('volume', 72)
    by_name['playlist-count']('playlist-count', 4)
    by_name['track-list']('track-list', { { type = 'audio', id = 1 } })
    by_name.metadata('metadata', { artist = 'Artist' })
    by_name['file-size']('file-size', 2048)
    F.eq(store:get().media_title, 'Episode 7', 'media title field')
    F.eq(store:get().time_pos, 12.5, 'time position field')
    F.eq(store:get().duration, 100, 'duration field')
    F.eq(store:get().percent_pos, 12.5, 'percent field')
    F.ok(store:get().pause, 'pause field')
    F.ok(store:get().fullscreen, 'window fullscreen field')
    F.eq(store:get().volume, 72, 'volume field')
    F.eq(store:get().playlist_count, 4, 'playlist count field')
    F.eq(store:get().track_list[1].id, 1, 'track list field')
    F.eq(store:get().metadata.artist, 'Artist', 'metadata field')
    F.eq(store:get().file_size, 2048, 'file size field')
    F.ok(store:get().media_title ~= nil, 'snapshot remains available as a view')
    context:dispose()
end)

F.test('HostActions keeps relative and absolute seek distinct', function()
    local calls = {}
    local actions = HostActions({
        seek = function(seconds) calls[#calls + 1] = { 'relative', seconds } end,
        seek_to = function(seconds) calls[#calls + 1] = { 'absolute', seconds } end,
    })
    actions:seek(-10)
    actions:seek_to(42.5)
    F.eq(calls[1][1], 'relative', 'relative seek action')
    F.eq(calls[1][2], -10, 'relative seek amount')
    F.eq(calls[2][1], 'absolute', 'absolute seek action')
    F.eq(calls[2][2], 42.5, 'absolute seek position')
end)

F.test('jump seek mode reaches the explicit host action', function()
    local mode
    local actions = HostActions({
        seek = function(_, selected_mode)
            mode = selected_mode
        end,
    })
    actions:seek(10, 'absolute')
    F.eq(mode, 'absolute', 'jump mode is preserved by HostActions')
end)

F.test('mpv action bridge emits distinct relative and absolute commands', function()
    mp_stub.reset()
    local actions = mpv_actions.default()
    actions:seek(-10)
    actions:seek_to(42.5)
    F.eq(fake.commands[1][1], 'seek', 'seek command name')
    F.eq(fake.commands[1][3], 'relative', 'relative command mode')
    F.eq(fake.commands[2][1], 'seek', 'absolute seek command name')
    F.eq(fake.commands[2][3], 'absolute+exact', 'absolute command mode')
end)

F.test('mpv play action replays at EOF and maximizes outside fullscreen', function()
    mp_stub.reset()
    fake.native_props['eof-reached'] = true
    local actions = mpv_actions.default()
    actions:play_pause()
    F.eq(fake.commands[1][1], 'seek', 'EOF play uses replay seek')
    F.eq(fake.commands[1][3], 'absolute+exact', 'EOF replay is exact')
    F.eq(fake.props.pause, false, 'EOF replay unpauses')

    mp_stub.reset()
    fake.native_props.fullscreen = false
    actions = mpv_actions.default()
    actions:toggle_maximized()
    F.eq(fake.commands[1][1], 'cycle', 'maximize uses cycle')
    F.eq(fake.commands[1][2], 'window-maximized', 'maximize targets window state')
end)

F.test('HostActions validates parameters and exposes capability presence', function()
    local actions = HostActions({ seek = function() end, set_volume = function() end })
    F.ok(actions:has('seek'), 'implemented action is available')
    F.ok(not actions:has('close'), 'missing action is unavailable')
    F.raises(function() actions:seek(math.huge) end,
        'finite number', 'seek rejects non-finite values')
    F.raises(function() actions:set_volume('loud' --[[@as number]]) end,
        'finite number', 'volume rejects non-number values')
    F.raises(function() actions:show_message('x', -1) end,
        'non-negative', 'message duration rejects negative values')
end)

F.test('HostActions bounds transient message payloads', function()
    local message = ''
    local actions = HostActions({
        show_message = function(value)
            message = value
        end,
    })
    actions:show_message(string.rep('x', 4001))
    F.eq(#message, 4000, 'message payload is capped at 4000 characters')
    F.eq(message:sub(-3), '...', 'capped message has an omission marker')
end)

F.test('HostActions validates and forwards external URL actions', function()
    local opened
    local actions = HostActions({
        open_url = function(url)
            opened = url
        end,
    })
    actions:open_url('https://example.test/watch')
    F.eq(opened, 'https://example.test/watch', 'open URL action reaches the host boundary')
    F.raises(function() actions:open_url('file:///tmp/nope') end,
        'http or https', 'open URL rejects non-web schemes')
end)

F.test('mpv action bridge maps common ModernX controls', function()
    mp_stub.reset()
    local actions = mpv_actions.default()
    actions:playlist_prev()
    actions:playlist_next()
    actions:chapter_prev()
    actions:chapter_next()
    actions:cycle_audio()
    actions:cycle_subtitle()
    actions:toggle_mute()
    actions:set_volume(75)
    actions:toggle_ontop()
    actions:screenshot('subtitles')
    actions:show_message('hello', 1.5)
    F.eq(fake.commands[1][1], 'playlist-prev', 'playlist previous command')
    F.eq(fake.commands[2][1], 'playlist-next', 'playlist next command')
    F.eq(fake.commands[3][1], 'add', 'chapter previous command')
    F.eq(fake.commands[4][3], '1', 'chapter next amount')
    F.eq(fake.commands[5][2], 'audio', 'audio cycle target')
    F.eq(fake.commands[6][2], 'sub', 'subtitle cycle target')
    F.eq(fake.commands[7][2], 'mute', 'mute cycle target')
    F.eq(fake.commands[8][3], '75', 'volume command value')
    F.eq(fake.commands[9][2], 'ontop', 'ontop cycle target')
    F.eq(fake.commands[10][2], 'subtitles', 'screenshot flag')
    F.eq(fake.commands[11][3], '1500', 'message duration in milliseconds')
end)

F.test('extended ModernX actions keep seek modes and control commands explicit', function()
    mp_stub.reset()
    local actions = mpv_actions.default()
    actions:seek_to(12.5, 'keyframe')
    actions:set_pause(true)
    actions:set_chapter(2)
    actions:set_track('audio', 3)
    actions:clear_secondary_subtitle()
    actions:select_subtitle()
    actions:select_audio_device()
    actions:frame_step()
    actions:playlist_shuffle()
    actions:select_playlist()
    F.eq(fake.commands[1][3], 'absolute', 'keyframe seek keeps the absolute mode')
    F.eq(fake.props.pause, true, 'pause setter reaches mpv')
    F.eq(fake.commands[2][2], 'chapter', 'chapter setter targets chapter')
    F.eq(fake.commands[3][2], 'audio', 'track setter targets audio')
    F.eq(fake.props['secondary-sid'], 0, 'subtitle cycle clears secondary subtitles')
    F.eq(fake.commands[4][2], 'select/select-sid', 'subtitle selector action')
    F.eq(fake.commands[5][2], 'select/select-audio-device', 'audio device selector action')
    F.eq(fake.commands[6][1], 'frame-step', 'frame step action')
    F.eq(fake.commands[7][1], 'playlist-shuffle', 'playlist shuffle action')
    F.eq(fake.commands[8][2], 'select/select-playlist', 'playlist selector action')
end)

F.test('thumbfast action bridge sends hover and clear messages', function()
    mp_stub.reset()
    local actions = mpv_actions.default()
    actions:thumbfast_request(42.5, 640, 612)
    actions:thumbfast_clear()
    F.eq(fake.commands[1][1], 'script-message-to', 'thumbfast request uses a script message')
    F.eq(fake.commands[1][2], 'thumbfast', 'thumbfast request target')
    F.eq(fake.commands[1][3], 'thumb', 'thumbfast request operation')
    F.eq(fake.commands[1][4], '42.5', 'thumbfast request seconds')
    F.eq(fake.commands[1][5], '640', 'thumbfast request x')
    F.eq(fake.commands[1][6], '612', 'thumbfast request y')
    F.eq(fake.commands[2][3], 'clear', 'thumbfast clear operation')
end)

F.test('default download action reports unavailable without async subprocess support', function()
    mp_stub.reset()
    local context = MpPlayerContext(PlayerStore({
        capabilities = { yt_dlp = { status = 'available' } },
    }))
    local actions = mpv_actions.default({ player_context = context })
    actions:download('https://example.test/video')
    F.eq(context.store:get():capability('download').status, 'unavailable',
        'download capability reports missing async support')
    F.eq(fake.commands[1][1], 'show-text', 'download unavailable emits a host message')
    context:dispose()
end)

F.test('default download action publishes loading and completed states', function()
    mp_stub.reset()
    local mp = package.loaded['mp']
    local callback
    mp.command_native_async = function(command, done)
        callback = done
        return { command = command }
    end
    mp.abort_async_command = function() end
    local context = MpPlayerContext(PlayerStore({
        capabilities = { yt_dlp = { status = 'available' } },
    }))
    local actions = mpv_actions.default({ player_context = context })
    actions:download('https://example.test/video')
    F.eq(context.store:get():capability('download').status, 'loading',
        'download publishes loading state')
    callback(true, { status = 0, stdout = 'done' })
    F.eq(context.store:get():capability('download').status, 'available',
        'download publishes completed state')
    F.eq(context.store:get():capability('download').detail, 'downloaded',
        'download retains completed detail')
    context:dispose()
    mp.command_native_async = nil
    mp.abort_async_command = nil
end)
