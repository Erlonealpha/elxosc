-- Fixed framework scenarios: no host dependency, timers or external integrations.
local basic_mod = require 'widget.widgets.basic'
local layout_mod = require 'widget.widgets.layout'
local style_mod = require 'text.text_style'
local geometry_mod = require 'foundation.geometry'
local app_mod = require 'widget.app'
local ambient_mod = require 'widget.ambient'
local player_mod = require 'widget.player_context'
local actions_mod = require 'widget.actions'
local main_mod = require 'widget.player.app'

local Text = basic_mod.Text
local Button = basic_mod.Button
local Row = layout_mod.Row
local Column = layout_mod.Column
local Padding = layout_mod.Padding
local EdgeInsets = geometry_mod.EdgeInsets
local text_style = style_mod.TextStyle({ font_size = 18, font_family = 'Arial', wrap = false })
local M = {}

local function noop()
end
local actions = actions_mod.HostActions({ seek = noop, seek_to = noop, play_pause = noop,
    set_volume = noop, toggle_mute = noop, toggle_fullscreen = noop, toggle_ontop = noop,
    playlist_prev = noop, playlist_next = noop, chapter_prev = noop, chapter_next = noop,
    minimize = noop, close = noop, set_track = noop })
local display = ambient_mod.DisplaySnapshot({ width = 1280, height = 720, initialized = true })

---@param text string
---@return Widget
local function label(text)
    return Text(text, { style = text_style })
end

---@param name string
---@param tick integer
---@return Widget
function M.build(name, tick)
    if name == 'small' then
        return Row({ spacing = 8, main_axis_size = 'min', children = {
            Button({ child = label('Play ' .. tick), on_pressed = noop }), label('00:24'),
        } })
    elseif name == 'deep' then
        local child = label('Depth ' .. tick)
        for _ = 1, 64 do
            child = Padding(child, { padding = EdgeInsets.all(1) })
        end
        return child
    elseif name == 'wide' then
        local children = {}
        for index = 1, 128 do
            children[index] = label(string.format('Item %03d %d', index, tick))
        end
        return Column({ children = children, main_axis_size = 'min', cross_alignment = 'start' })
    elseif name == 'player' then
        local snapshot = player_mod.PlayerSnapshot({ duration = 600, time_pos = 100 + tick % 100,
            percent_pos = (100 + tick % 100) / 6, pause = true, volume = 72, volume_max = 100,
            media_title = 'Benchmark player', chapter = 1,
            chapter_list = { { time = 0, title = 'Opening' }, { time = 90, title = 'Chapter' } },
            track_list = { { type = 'audio', id = 1 }, { type = 'sub', id = 1 } } })
        return app_mod.WidgetsApp({ display = display, actions = actions,
            child = player_mod.PlayerProvider({ snapshot = snapshot,
                child = main_mod.Main({ scale = 1.5 }) }) })
    end
    error('unknown benchmark scene: ' .. name)
end

M.names = { 'small', 'deep', 'wide', 'player' }
return M
