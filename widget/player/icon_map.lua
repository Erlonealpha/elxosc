-- ModernX semantic icon names mapped to the bundled Material Symbols glyphs.
-- The map is intentionally private so callers cannot mutate the public contract.

local icon_widgets = require 'widget.widgets.icon'
local geometry = require 'foundation.geometry'

local Icon = icon_widgets.Icon
local Offset = geometry.Offset

local M = {}

---@alias ModernXIconName
--- | 'play'
--- | 'idle'
--- | 'pause'
--- | 'replay'
--- | 'previous'
--- | 'next'
--- | 'rewind'
--- | 'rewind_5'
--- | 'rewind_10'
--- | 'rewind_30'
--- | 'forward'
--- | 'forward_5'
--- | 'forward_10'
--- | 'forward_30'
--- | 'audio'
--- | 'subtitle'
--- | 'subtitle_off'
--- | 'volume_mute'
--- | 'volume_down'
--- | 'volume_up'
--- | 'volume_off'
--- | 'fullscreen'
--- | 'fullscreen_exit'
--- | 'open_in_full'
--- | 'close_fullscreen'
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

---@class ModernXIconSpec
---@field glyph FluentIconNames
---@field size number
---@field font_family FluentIconFontName
---@field fill number
---@field weight number
---@field grade number
---@field optical_size number
---@field optical_offset Offset

---@class _ModernXIconSeed
---@field glyph FluentIconNames
---@field size number
---@field font_family FluentIconFontName?
---@field fill number?
---@field weight number?
---@field grade number?
---@field optical_size number?
---@field optical_offset Offset?

local ICON_FONT = 'Material Symbols Rounded'
local ZERO = Offset.zero()

---@type table<ModernXIconName, _ModernXIconSeed>
local specs = {
    play = { glyph = 'play_arrow', size = 30 },
    idle = { glyph = 'play_circle', size = 64 },
    pause = { glyph = 'pause', size = 30 },
    replay = { glyph = 'replay', size = 30 },
    previous = { glyph = 'skip_previous', size = 24 },
    next = { glyph = 'skip_next', size = 24 },
    rewind = { glyph = 'fast_rewind', size = 24 },
    rewind_5 = { glyph = 'replay_5', size = 24 },
    rewind_10 = { glyph = 'replay_10', size = 24 },
    rewind_30 = { glyph = 'replay_30', size = 24 },
    forward = { glyph = 'fast_forward', size = 24 },
    forward_5 = { glyph = 'forward_5', size = 24 },
    forward_10 = { glyph = 'forward_10', size = 24 },
    forward_30 = { glyph = 'forward_30', size = 24 },
    audio = { glyph = 'audio_file', size = 24 },
    subtitle = { glyph = 'subtitles', size = 24 },
    subtitle_off = { glyph = 'subtitles_off', size = 24 },
    volume_mute = { glyph = 'volume_mute', size = 24 },
    volume_down = { glyph = 'volume_down', size = 24 },
    volume_up = { glyph = 'volume_up', size = 24 },
    volume_off = { glyph = 'volume_off', size = 24 },
    fullscreen = { glyph = 'fullscreen', size = 24 },
    fullscreen_exit = { glyph = 'fullscreen_exit', size = 24 },
    open_in_full = { glyph = 'open_in_full', size = 24 },
    close_fullscreen = { glyph = 'close_fullscreen', size = 24 },
    pinned = { glyph = 'push_pin', size = 24 },
    unpinned = { glyph = 'push_pin', size = 24 },
    loop = { glyph = 'repeat', size = 24 },
    loop_on = { glyph = 'repeat_on', size = 24 },
    download = { glyph = 'download', size = 24 },
    download_done = { glyph = 'download_done', size = 24 },
    info = { glyph = 'info', size = 24 },
    screenshot = { glyph = 'screenshot', size = 24 },
    minimize = { glyph = 'minimize', size = 18 },
    maximize = { glyph = 'maximize', size = 18 },
    close = { glyph = 'close', size = 18 },
}

for _, spec in pairs(specs) do
    spec.font_family = ICON_FONT
    spec.fill = 0
    spec.weight = 400
    spec.grade = 0
    spec.optical_size = 24
    spec.optical_offset = ZERO
end

local function get_spec(name)
    local spec = specs[name]
    if spec == nil then
        error('unknown ModernX icon: ' .. tostring(name), 3)
    end
    return spec --[[@as ModernXIconSpec]]
end

---@param name ModernXIconName
---@return ModernXIconSpec
function M.spec(name)
    local source = get_spec(name)
    return {
        glyph = source.glyph,
        size = source.size,
        font_family = source.font_family,
        fill = source.fill,
        weight = source.weight,
        grade = source.grade,
        optical_size = source.optical_size,
        optical_offset = Offset(source.optical_offset.x, source.optical_offset.y),
    }
end

---@param name ModernXIconName
---@return FluentIconNames
function M.glyph_name(name)
    return get_spec(name).glyph
end

---@param name ModernXIconName
---@param options _IconOptions?
---@return Icon
function M.icon(name, options)
    local spec = get_spec(name)
    local merged = {
        size = spec.size,
        font_family = spec.font_family,
        fill = spec.fill,
        weight = spec.weight,
        grade = spec.grade,
        optical_size = spec.optical_size,
        optical_offset = Offset(spec.optical_offset.x, spec.optical_offset.y),
    }
    for key, value in pairs(options or {}) do
        merged[key] = value
    end
    return Icon(spec.glyph, merged)
end

return M
