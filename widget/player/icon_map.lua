-- ModernX semantic icon names mapped to the bundled Material Symbols glyphs.
-- The map is intentionally private so callers cannot mutate the public contract.

local icon_widgets = require 'widget.widgets.icon'

local Icon = icon_widgets.Icon

local M = {}

---@alias ModernXIconName
--- | 'play'
--- | 'pause'
--- | 'replay'
--- | 'previous'
--- | 'next'
--- | 'rewind'
--- | 'forward'
--- | 'audio'
--- | 'subtitle'
--- | 'subtitle_off'
--- | 'volume_mute'
--- | 'volume_down'
--- | 'volume_up'
--- | 'volume_off'
--- | 'fullscreen'
--- | 'fullscreen_exit'
--- | 'pinned'
--- | 'unpinned'
--- | 'loop'
--- | 'loop_on'
--- | 'download'
--- | 'download_done'
--- | 'info'
--- | 'screenshot'
--- | 'minimize'
--- | 'maximize'
--- | 'close'

---@type table<ModernXIconName, FluentIconNames>
local glyphs = {
    play = 'play_arrow',
    pause = 'pause',
    replay = 'replay',
    previous = 'skip_previous',
    next = 'skip_next',
    rewind = 'fast_rewind',
    forward = 'fast_forward',
    audio = 'audio_file',
    subtitle = 'subtitles',
    subtitle_off = 'subtitles_off',
    volume_mute = 'volume_mute',
    volume_down = 'volume_down',
    volume_up = 'volume_up',
    volume_off = 'volume_off',
    fullscreen = 'fullscreen',
    fullscreen_exit = 'fullscreen_exit',
    pinned = 'push_pin',
    unpinned = 'push_pin',
    loop = 'repeat',
    loop_on = 'repeat_on',
    download = 'download',
    download_done = 'download_done',
    info = 'info',
    screenshot = 'screenshot',
    minimize = 'minimize',
    maximize = 'maximize',
    close = 'close',
}

---@param name ModernXIconName
---@return FluentIconNames
function M.glyph_name(name)
    local glyph = glyphs[name]
    if glyph == nil then
        error('unknown ModernX icon: ' .. tostring(name), 2)
    end
    return glyph
end

---@param name ModernXIconName
---@param options _IconOptions?
---@return Icon
function M.icon(name, options)
    return Icon(M.glyph_name(name), options)
end

return M
