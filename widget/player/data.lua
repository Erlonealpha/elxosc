-- Player snapshot selectors, time formatting and timeline/track data.

local max = math.max
local min = math.min
local huge = math.huge
local color_mod = require 'foundation.color'
local Color = color_mod.Color
local SPONSOR_COLORS = {
    sponsor = Color.hex('#6BCB77'),
    intro = Color.hex('#FFD166'),
    outro = Color.hex('#4D96FF'),
    interaction = Color.hex('#C77DFF'),
    selfpromo = Color.hex('#FF9F1C'),
    preview = Color.hex('#00B4D8'),
    filler = Color.hex('#8D99AE'),
}

local M = {}

local function snapshot_text(snapshot, names, fallback)
    if snapshot then
        for _, name in ipairs(names) do
            local value = snapshot:get(name)
            if (type(value) == 'string' or type(value) == 'number') and tostring(value) ~= '' then
                return tostring(value)
            end
        end
    end
    return fallback
end

local function snapshot_number(snapshot, name)
    local value = snapshot and snapshot:get(name) or nil
    if type(value) ~= 'number' or value ~= value or value == huge or value == -huge then
        return nil
    end
    return value
end

---@param snapshot PlayerSnapshot?
---@param name string
---@return boolean
local function capability_available(snapshot, name)
    if snapshot == nil or type(snapshot.capability) ~= 'function' then
        return false
    end
    return snapshot:capability(name).status == 'available'
end

---@param snapshot PlayerSnapshot?
---@param name string
---@return CapabilityInfo?
local function capability_info(snapshot, name)
    if snapshot == nil then
        return nil
    end
    local capabilities = snapshot:get('capabilities')
    if type(capabilities) ~= 'table' or capabilities[name] == nil
        or type(snapshot.capability) ~= 'function' then
        return nil
    end
    return snapshot:capability(name)
end
---@param source table?
---@return any[]
local function array_items(source)
    local values = {}
    if type(source) ~= 'table' then
        return values
    end
    local index = 1
    while source[index] ~= nil do
        values[#values + 1] = source[index]
        index = index + 1
    end
    return values
end

---@param snapshot PlayerSnapshot?
---@return table[]
local function chapter_entries(snapshot)
    local source = snapshot and snapshot:get('chapter_list') or nil
    if type(source) ~= 'table' then
        return {}
    end
    local entries = {}
    for _, chapter in ipairs(array_items(source)) do
        if type(chapter) == 'table' then
            entries[#entries + 1] = chapter
        end
    end
    table.sort(entries, function(left, right)
        return (tonumber(left.time) or huge) < (tonumber(right.time) or huge)
    end)
    return entries
end

---@param snapshot PlayerSnapshot?
---@return string
local function current_chapter_title(snapshot)
    if snapshot and snapshot:get('buffering') == true then
        return 'Buffering...'
    end
    local explicit = snapshot_text(snapshot, { 'chapter_title' }, '')
    if explicit ~= '' then
        return explicit
    end
    local index = snapshot_number(snapshot, 'chapter')
    local chapters = chapter_entries(snapshot)
    if index == nil or #chapters == 0 or index < 0 then
        return ''
    end
    local chapter = chapters[index + 1]
    if type(chapter) == 'table' and type(chapter.title) == 'string' and chapter.title ~= '' then
        return chapter.title
    end
    return ''
end

local function clamp_fraction(value)
    return max(0, min(1, value))
end

local function format_time(value, show_milliseconds, fixed)
    if value == nil or value < 0 then
        return '--:--'
    end
    local total = math.floor(value)
    local seconds = total % 60
    local minutes = math.floor(total / 60) % 60
    local hours = math.floor(total / 3600)
    local milliseconds = math.floor((value - total) * 1000 + 0.5)
    if milliseconds >= 1000 then
        seconds = seconds + 1
        milliseconds = 0
    end
    if show_milliseconds then
        if hours > 0 or fixed then
            return string.format('%02d:%02d:%02d.%03d', hours, minutes, seconds, milliseconds)
        end
        return string.format('%02d:%02d.%03d', minutes, seconds, milliseconds)
    end
    if fixed and hours == 0 then
        return string.format('00:%02d:%02d', minutes, seconds)
    end
    if hours > 0 then
        return string.format('%d:%02d:%02d', hours, minutes, seconds)
    end
    return string.format('%02d:%02d', minutes, seconds)
end

---@param snapshot PlayerSnapshot?
---@param fraction number
---@param duration number?
---@return string?
local function chapter_title_at_fraction(snapshot, fraction, duration)
    if duration == nil or duration <= 0 then
        return nil
    end
    local selected
    for index, chapter in ipairs(chapter_entries(snapshot)) do
        local time = tonumber(chapter.time)
        if time and time <= fraction * duration then
            selected = { chapter = chapter, index = index }
        elseif time and time > fraction * duration then
            break
        end
    end
    if not selected then
        return nil
    end
    local title = selected.chapter.title
    if type(title) == 'string' and title ~= '' then
        return title
    end
    return nil
end
local function player_progress(snapshot)
    local percent = snapshot_number(snapshot, 'percent_pos')
    if percent ~= nil then
        return clamp_fraction(percent / 100)
    end
    local position = snapshot_number(snapshot, 'time_pos')
    local duration = snapshot_number(snapshot, 'duration')
    if position ~= nil and duration ~= nil and duration > 0 then
        return clamp_fraction(position / duration)
    end
    return 0
end

---@param snapshot PlayerSnapshot?
---@param duration number?
---@return table[]
local function chapter_markers(snapshot, duration)
    local chapters = chapter_entries(snapshot)
    if #chapters == 0 or duration == nil or duration <= 0 then
        return {}
    end
    local current = snapshot_number(snapshot, 'chapter')
    local markers = {}
    for index, chapter in ipairs(chapters) do
        if type(chapter) == 'table' then
            local time = tonumber(chapter.time)
            if time and time >= 0 then
                markers[#markers + 1] = {
                    fraction = clamp_fraction(time / duration),
                    current = current ~= nil and current == index - 1,
                    index = index - 1,
                }
            end
        end
    end
    return markers
end

---@param snapshot PlayerSnapshot?
---@param duration number?
---@return table[]
local function seek_ranges(snapshot, duration)
    if snapshot == nil or duration == nil or duration <= 0 then
        return {}
    end
    local source = snapshot:get('seekable_ranges')
    if source == nil then
        local cache_state = snapshot:get('cache_state')
        source = type(cache_state) == 'table' and cache_state['seekable-ranges'] or nil
    end
    if type(source) ~= 'table' then
        return {}
    end
    local ranges = {}
    for _, range in ipairs(array_items(source)) do
        if type(range) == 'table' then
            local start = tonumber(range.start or range[1])
            local finish = tonumber(range['end'] or range.finish or range[2])
            if start and finish then
                ranges[#ranges + 1] = {
                    start = clamp_fraction(start / duration),
                    ['end'] = clamp_fraction(finish / duration),
                }
            end
        end
    end
    return ranges
end

---@param snapshot PlayerSnapshot?
---@param duration number?
---@return table[]
local function sponsor_ranges(snapshot, duration)
    if snapshot == nil or duration == nil or duration <= 0 then
        return {}
    end
    local source = snapshot:get('sponsor_segments')
    if type(source) ~= 'table' then
        return {}
    end
    local ranges = {}
    for _, segment in ipairs(array_items(source)) do
        if type(segment) == 'table' then
            local start = tonumber(segment.start or segment[1])
            local finish = tonumber(segment['end'] or segment.finish or segment[2])
            if start and finish then
                ranges[#ranges + 1] = {
                    start = clamp_fraction(start / duration),
                    ['end'] = clamp_fraction(finish / duration),
                    color = SPONSOR_COLORS[segment.category],
                }
            end
        end
    end
    return ranges
end

---@param snapshot PlayerSnapshot?
---@param kind 'audio'|'sub'
---@return number[]
local function track_ids(snapshot, kind)
    local ids = {}
    local tracks = snapshot and snapshot:get('track_list') or nil
    if type(tracks) ~= 'table' then
        return ids
    end
    for _, track in ipairs(array_items(tracks)) do
        if type(track) == 'table' and track.type == kind then
            local id = tonumber(track.id)
            if id ~= nil then
                ids[#ids + 1] = id
            end
        end
    end
    table.sort(ids)
    return ids
end

---@param snapshot PlayerSnapshot?
---@param kind 'audio'|'sub'
---@return number
local function current_track(snapshot, kind)
    local tracks = snapshot and snapshot:get('track_list') or nil
    if type(tracks) == 'table' then
        for _, track in ipairs(array_items(tracks)) do
            if type(track) == 'table' and track.type == kind and track.selected == true then
                return tonumber(track.id) or 0
            end
        end
    end
    return 0
end

---@param snapshot PlayerSnapshot?
---@param kind 'audio'|'sub'
---@return string
local function track_tooltip(snapshot, kind)
    local label = kind == 'audio' and 'Audio' or 'Subtitles'
    local unavailable = kind == 'audio' and 'No audio available' or 'No subtitles available'
    local tracks = snapshot and snapshot:get('track_list') or nil
    if type(tracks) ~= 'table' then
        return label
    end
    local matching = {}
    local selected
    for _, track in ipairs(array_items(tracks)) do
        if type(track) == 'table' and track.type == kind then
            matching[#matching + 1] = track
            if track.selected == true then
                selected = track
            end
        end
    end
    if #matching == 0 then
        return unavailable
    end
    if selected == nil then
        return label .. ' off'
    end
    local selected_data = selected --[[@as table<string, any>]]
    local id = tonumber(selected_data.id)
    local suffix = id and string.format(' [%d / %d]', id, #matching) or ''
    local language = type(selected_data.lang) == 'string' and selected_data.lang or ''
    local title = type(selected_data.title) == 'string' and selected_data.title or ''
    local details = language ~= '' and language or title
    if language ~= '' and title ~= '' then
        details = language .. ' ' .. title
    end
    if details ~= '' then
        suffix = suffix .. ' ' .. details
    end
    return label .. suffix
end

---@param snapshot PlayerSnapshot?
---@param kind 'audio'|'sub'
---@return string
local function track_list_message(snapshot, kind)
    local label = kind == 'audio' and 'Audio' or 'Subtitles'
    local tracks = snapshot and snapshot:get('track_list') or nil
    if type(tracks) ~= 'table' then
        return label .. ': unavailable'
    end
    local names = {}
    for index, track in ipairs(array_items(tracks)) do
        if type(track) == 'table' and track.type == kind then
            local id = tonumber(track.id) or index
            local title = type(track.title) == 'string' and track.title or ''
            local language = type(track.lang) == 'string' and track.lang or ''
            local details = title ~= '' and title or language
            names[#names + 1] = details ~= '' and (id .. ': ' .. details) or tostring(id)
        end
    end
    if #names == 0 then
        return label .. ': unavailable'
    end
    return label .. ': ' .. table.concat(names, ', ')
end

---@param snapshot PlayerSnapshot?
---@param kind 'audio'|'sub'
---@param delta number
---@return number?
local function next_track(snapshot, kind, delta)
    local ids = track_ids(snapshot, kind)
    if #ids == 0 then
        return nil
    end
    local current = current_track(snapshot, kind)
    local position = 0
    for index, id in ipairs(ids) do
        if id == current then
            position = index
            break
        end
    end
    if delta > 0 then
        position = position + 1
        if position > #ids then
            return 0
        end
        return ids[position]
    end
    position = position - 1
    if position <= 0 then
        return ids[#ids]
    end
    return ids[position]
end

---@param snapshot PlayerSnapshot?
---@param fraction number
---@param duration number?
---@return number?
local function nearest_chapter(snapshot, fraction, duration)
    local chapters = chapter_markers(snapshot, duration)
    local best, distance
    for index, marker in ipairs(chapters) do
        local current_distance = math.abs(marker.fraction - fraction)
        if distance == nil or current_distance < distance then
            distance = current_distance
            best = marker.index or index - 1
        end
    end
    return best
end

M.snapshot_text = snapshot_text
M.snapshot_number = snapshot_number
M.capability_available = capability_available
M.capability_info = capability_info
M.array_items = array_items
M.chapter_entries = chapter_entries
M.current_chapter_title = current_chapter_title
M.clamp_fraction = clamp_fraction
M.format_time = format_time
M.chapter_title_at_fraction = chapter_title_at_fraction
M.player_progress = player_progress
M.chapter_markers = chapter_markers
M.seek_ranges = seek_ranges
M.sponsor_ranges = sponsor_ranges
M.track_ids = track_ids
M.current_track = current_track
M.track_tooltip = track_tooltip
M.track_list_message = track_list_message
M.next_track = next_track
M.nearest_chapter = nearest_chapter

return M
