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
            mp.commandv('cycle', 'pause')
        end,
        seek = function(seconds)
            mp.commandv('seek', tostring(seconds), 'relative')
        end,
        toggle_fullscreen = function()
            mp.commandv('cycle', 'fullscreen')
        end,
        minimize = function()
            mp.commandv('cycle', 'window-minimized')
        end,
        close = function()
            mp.commandv('quit')
        end,
    })
end

M.HostActions = HostActions

return M
