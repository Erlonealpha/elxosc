-- Host-independent metadata normalization for the default player.

local M = {}

local function snapshot_value(snapshot, name)
    if snapshot and type(snapshot.get) == 'function' then
        return snapshot:get(name)
    end
    return nil
end

local function text(value)
    if type(value) ~= 'string' and type(value) ~= 'number' then
        return nil
    end
    value = tostring(value):gsub('^%s+', ''):gsub('%s+$', '')
    return value ~= '' and value or nil
end

local function metadata(snapshot)
    local value = snapshot_value(snapshot, 'metadata')
    return type(value) == 'table' and value or {}
end

local function metadata_value(snapshot, names)
    local values = metadata(snapshot)
    for _, name in ipairs(names) do
        local value = text(values[name])
        if value then
            return value
        end
    end
    return nil
end

---@param snapshot PlayerSnapshot?
---@param direct string[]
---@param nested string[]?
---@return string?
local function first_text(snapshot, direct, nested)
    for _, name in ipairs(direct) do
        local value = text(snapshot_value(snapshot, name))
        if value then
            return value
        end
    end
    return nested and metadata_value(snapshot, nested) or nil
end

---@param snapshot PlayerSnapshot?
---@return boolean
function M.is_url(snapshot)
    local explicit = snapshot_value(snapshot, 'is_url')
    if type(explicit) == 'boolean' then
        return explicit
    end
    local source = first_text(snapshot, { 'url', 'path', 'filename' }, { 'url' })
    return source ~= nil and source:match('^[%a][%w+.-]*://') ~= nil
end

---@param snapshot PlayerSnapshot?
---@return boolean
function M.is_live(snapshot)
    local explicit = snapshot_value(snapshot, 'is_live')
    if type(explicit) == 'boolean' then
        return explicit
    end
    local value = metadata_value(snapshot, { 'ytdl_is_live', 'is_live', 'live' })
    return value == 'yes' or value == 'true' or value == '1' or value == 'live'
end

---@param value string
---@return string
local function format_date(value)
    if value:match('^%d%d%d%d%d%d%d%d$') then
        return value:sub(1, 4) .. '-' .. value:sub(5, 6) .. '-' .. value:sub(7, 8)
    end
    if value:match('^%d%d%d%d%d%d$') then
        return value:sub(1, 4) .. '-' .. value:sub(5, 6)
    end
    return value
end

---@param bytes number?
---@return string?
function M.format_file_size(bytes)
    bytes = tonumber(bytes)
    if bytes == nil or bytes < 0 or bytes ~= bytes or bytes == math.huge or bytes == -math.huge then
        return nil
    end
    local units = { 'B', 'KiB', 'MiB', 'GiB', 'TiB' }
    local index = 1
    while bytes >= 1024 and index < #units do
        bytes = bytes / 1024
        index = index + 1
    end
    if index == 1 then
        return string.format('%d %s', math.floor(bytes + 0.5), units[index])
    end
    return string.format('%.1f %s', bytes, units[index])
end

---@param snapshot PlayerSnapshot?
---@return string
function M.title(snapshot, fallback)
    local value = first_text(snapshot, { 'media_title', 'title', 'filename' }, { 'title' })
    if value then
        return value
    end
    if M.is_url(snapshot) then
        return 'Loading...'
    end
    return fallback or 'elxosc'
end

---@param snapshot PlayerSnapshot?
---@return string
function M.description(snapshot)
    local explicit = first_text(snapshot, { 'description', 'media_description' }, { 'description' })
    if explicit then
        return explicit
    end

    local artist = metadata_value(snapshot, { 'album_artist', 'artist', 'uploader' })
    local album = metadata_value(snapshot, { 'album' })
    local date = metadata_value(snapshot, { 'date', 'upload_date' })
    local size = M.format_file_size(snapshot_value(snapshot, 'file_size'))
        or M.format_file_size(metadata(snapshot).filesize)
        or M.format_file_size(metadata(snapshot).filesize_approx)
    local parts = {}
    if artist then
        parts[#parts + 1] = artist
    end
    if album then
        parts[#parts + 1] = album
    end
    if date then
        parts[#parts + 1] = format_date(date)
    end
    if size then
        parts[#parts + 1] = size
    end
    if #parts > 0 then
        return table.concat(parts, ' · ')
    end
    if M.is_url(snapshot) then
        return 'Loading description...'
    end
    return ''
end

---@param value string
---@param limit number?
---@return string
function M.preview(value, limit)
    limit = limit or 240
    if #value <= limit then
        return value
    end
    local end_index = math.floor(math.max(0, limit - 3)) --[[@as integer]]
    return value:sub(1, end_index) .. '...'
end

M.metadata = metadata

return M
