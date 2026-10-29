-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- The default mpv implementation of the small, explicit HostActions contract.

local mp = require 'mp'

local actions_mod = require 'widget.actions'

local HostActions = actions_mod.HostActions

local M = {}

---@return HostActions
function M.default()
    return HostActions({
        play_pause = function()
            if mp.get_property_native('eof-reached') == true then
                mp.commandv('seek', '0', 'absolute+exact')
                mp.set_property('pause', false)
            else
                mp.commandv('cycle', 'pause')
            end
        end,
        replay = function()
            mp.commandv('seek', '0', 'absolute+exact')
            mp.set_property('pause', false)
        end,
        seek = function(seconds)
            mp.commandv('seek', tostring(seconds), 'relative')
        end,
        seek_to = function(seconds)
            mp.commandv('seek', tostring(seconds), 'absolute+exact')
        end,
        playlist_prev = function()
            mp.commandv('playlist-prev', 'weak')
        end,
        playlist_next = function()
            mp.commandv('playlist-next', 'weak')
        end,
        chapter_prev = function()
            mp.commandv('add', 'chapter', '-1')
        end,
        chapter_next = function()
            mp.commandv('add', 'chapter', '1')
        end,
        cycle_audio = function()
            mp.commandv('cycle', 'audio')
        end,
        cycle_subtitle = function()
            mp.commandv('cycle', 'sub')
        end,
        toggle_mute = function()
            mp.commandv('cycle', 'mute')
        end,
        set_volume = function(volume)
            mp.commandv('set', 'volume', tostring(volume))
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
        screenshot = function(flag)
            if flag then
                mp.commandv('screenshot', flag)
            else
                mp.commandv('screenshot')
            end
        end,
        show_message = function(message, duration)
            if duration == nil then
                mp.commandv('show-text', message)
            else
                mp.commandv('show-text', message, tostring(duration * 1000))
            end
        end,
        close = function()
            mp.commandv('quit')
        end,
    })
end

M.HostActions = HostActions

return M
