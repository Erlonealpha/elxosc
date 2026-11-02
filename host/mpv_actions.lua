-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- The default mpv implementation of the small, explicit HostActions contract.

local mp = require 'mp'

local actions_mod = require 'widget.actions'

local HostActions = actions_mod.HostActions

local M = {}

local function open_url_command(url)
    local separator = package.config and package.config:sub(1, 1) or '\\'
    if separator == '\\' then
        return { 'cmd.exe', '/c', 'start', '', url }
    end
    return { 'xdg-open', url }
end

---@return HostActions
---@param options? { player_context: MpPlayerContext? }
function M.default(options)
    options = options or {}
    local player_context = options.player_context
    local function set_capability(status, detail, error_message)
        if player_context and type(player_context.set_capability) == 'function' then
            pcall(player_context.set_capability, player_context,
                'download', status, detail, error_message)
        end
    end
    return HostActions({
        play_pause = function()
            if mp.get_property_native('eof-reached') == true then
                mp.commandv('seek', '0', 'absolute+exact')
                mp.set_property_native('pause', false)
            else
                mp.commandv('cycle', 'pause')
            end
        end,
        replay = function()
            mp.commandv('seek', '0', 'absolute+exact')
            mp.set_property_native('pause', false)
        end,
        seek = function(seconds, mode)
            mp.commandv('seek', tostring(seconds), mode or 'relative')
        end,
        seek_to = function(seconds, mode)
            local flags = mode == 'keyframe' and 'absolute' or 'absolute+exact'
            mp.commandv('seek', tostring(seconds), flags)
        end,
        set_pause = function(paused)
            mp.set_property_native('pause', paused)
        end,
        thumbfast_request = function(seconds, x, y)
            mp.commandv('script-message-to', 'thumbfast', 'thumb',
                tostring(seconds), tostring(x), tostring(y))
        end,
        thumbfast_clear = function()
            mp.commandv('script-message-to', 'thumbfast', 'clear')
        end,
        open_url = function(url)
            local runtime_mp = package.loaded['mp'] or mp
            if type(runtime_mp.command_native_async) == 'function' then
                runtime_mp.command_native_async({
                    name = 'subprocess',
                    args = open_url_command(url),
                    playback_only = false,
                }, function() end)
            else
                local command = open_url_command(url)
                runtime_mp.commandv('run', table.unpack(command))
            end
        end,
        playlist_prev = function()
            mp.commandv('playlist-prev', 'weak')
        end,
        playlist_next = function()
            mp.commandv('playlist-next', 'weak')
        end,
        select_playlist = function()
            mp.commandv('script-binding', 'select/select-playlist')
        end,
        chapter_prev = function()
            mp.commandv('add', 'chapter', '-1')
        end,
        chapter_next = function()
            mp.commandv('add', 'chapter', '1')
        end,
        set_chapter = function(index)
            mp.commandv('set', 'chapter', tostring(index))
        end,
        select_chapter = function()
            mp.commandv('script-binding', 'select/select-chapter')
        end,
        set_track = function(kind, id)
            local property = kind == 'audio' and 'audio' or 'sid'
            local value = id == 0 and 'no' or tostring(id)
            mp.commandv('set', property, value)
        end,
        clear_audio_filter = function()
            mp.set_property('lavfi-complex', '')
        end,
        select_audio_track = function()
            mp.commandv('script-binding', 'select/select-aid')
        end,
        load_audio_track = function()
            mp.commandv('script-binding', 'loadaudiotracks/ask_for_audio_track')
        end,
        clear_secondary_subtitle = function()
            mp.set_property_native('secondary-sid', 0)
        end,
        select_subtitle = function()
            mp.commandv('script-binding', 'select/select-sid')
        end,
        cycle_audio = function()
            mp.commandv('cycle', 'audio')
        end,
        cycle_audio_reverse = function()
            mp.commandv('cycle', 'audio', 'down')
        end,
        cycle_subtitle = function()
            mp.commandv('cycle', 'sub')
        end,
        cycle_subtitle_reverse = function()
            mp.commandv('cycle', 'sub', 'down')
        end,
        toggle_mute = function()
            mp.commandv('cycle', 'mute')
        end,
        set_volume = function(volume)
            mp.commandv('set', 'volume', tostring(volume))
        end,
        select_audio_device = function()
            mp.commandv('script-binding', 'select/select-audio-device')
        end,
        frame_step = function()
            mp.commandv('frame-step')
        end,
        frame_back_step = function()
            mp.commandv('frame-back-step')
        end,
        toggle_fullscreen = function()
            mp.commandv('cycle', 'fullscreen')
        end,
        toggle_maximized = function()
            if mp.get_property_native('fullscreen') == true then
                mp.commandv('cycle', 'fullscreen')
            else
                mp.commandv('cycle', 'window-maximized')
            end
        end,
        minimize = function()
            mp.commandv('cycle', 'window-minimized')
        end,
        toggle_ontop = function()
            mp.commandv('cycle', 'ontop')
        end,
        toggle_loop = function()
            mp.commandv('cycle', 'loop-file')
        end,
        screenshot = function(flag)
            if flag then
                mp.commandv('screenshot', flag)
            else
                mp.commandv('screenshot')
            end
        end,
        show_stats = function()
            mp.commandv('script-binding', 'stats/display-stats-toggle')
        end,
        show_message = function(message, duration)
            if duration == nil then
                mp.commandv('show-text', message)
            else
                mp.commandv('show-text', message, tostring(duration * 1000))
            end
        end,
        download = function(url)
            local runtime_mp = package.loaded['mp'] or mp
            if player_context then
                local current = player_context.store:get():capability('download')
                if current.status == 'loading' then
                    runtime_mp.commandv('show-text', 'Download in progress')
                    return
                end
                if current.status == 'available' and current.detail == 'downloaded' then
                    runtime_mp.commandv('show-text', 'Already downloaded')
                    return
                end
            end
            if type(runtime_mp.command_native_async) ~= 'function' then
                set_capability('unavailable', 'async subprocess API unavailable')
                runtime_mp.commandv('show-text', 'Download unavailable')
                return
            end
            set_capability('loading', 'downloading')
            local finished = false
            local request
            local release
            local function finish(status, detail, error_message, message)
                if finished then
                    return
                end
                finished = true
                if release then
                    release()
                    release = nil
                end
                set_capability(status, detail, error_message)
                if message then
                    runtime_mp.commandv('show-text', message)
                end
            end
            request = runtime_mp.command_native_async({
                name = 'subprocess',
                args = {
                    'yt-dlp', '--no-playlist', '--remux-video', 'mp4',
                    '-o', '%(title)s.%(ext)s', url,
                },
                playback_only = false,
                capture_stdout = true,
                capture_stderr = true,
            }, function(success, result, error_message)
                if success and type(result) == 'table' and (result.status == nil or result.status == 0) then
                    finish('available', 'downloaded', nil, 'Download completed')
                else
                    finish('error', 'download failed', tostring(error_message or 'download failed'),
                        'Download failed')
                end
            end)
            if player_context and type(player_context.register_async) == 'function' then
                release = player_context:register_async(function()
                    finished = true
                    if request and type(runtime_mp.abort_async_command) == 'function' then
                        runtime_mp.abort_async_command(request)
                    end
                end)
            end
        end,
        close = function()
            mp.commandv('quit')
        end,
        playlist_shuffle = function()
            mp.commandv('playlist-shuffle')
        end,
        playlist_first = function()
            mp.commandv('set', 'playlist-pos', '0')
        end,
        playlist_last = function()
            local count = mp.get_property_number('playlist-count') or 1
            mp.commandv('set', 'playlist-pos', tostring(math.max(0, count - 1)))
        end,
    })
end

M.HostActions = HostActions

return M
