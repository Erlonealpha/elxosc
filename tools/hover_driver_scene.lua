-- Versioned deterministic traces; no mp dependency or implicit external media updates.
---@namespace elxosc.tools.hover
local M = {}

M.names = { 'paused-fixed', 'paused-ms', 'playing', 'stationary', 'burst', 'clean',
    'data-pressure', 'environment', 'preview' }

---@param name string
---@param frames integer
---@return table
function M.build(name, frames, options)
    options = options or {}
    assert(options.style_updates == nil or type(options.style_updates) == 'boolean',
        'style_updates must be a boolean')
    local known = false
    for _, candidate in ipairs(M.names) do
        known = known or name == candidate
    end
    assert(known, 'unknown hover scene')
    assert(type(frames) == 'number' and frames == math.floor(frames) and frames >= 0 and frames <= 512,
        'frames must be an integer in 0..512')
    local playing = name == 'playing' or name == 'stationary' or name == 'data-pressure'
    local steps = {}
    for index = 1, frames do
        local step = { seq = index, time = index / 240, moves = {} }
        local count = name == 'burst' and (options.burst_moves or 4) or 1
        assert(count == 1 or count == 4 or count == 16, 'burst moves must be 1, 4 or 16')
        if name == 'clean' or name == 'stationary' and index > 1 then
            count = 0
        end
        for move = 1, count do
            step.moves[move] = { x = name == 'paused-fixed' and 200 + index % 2 * 0.05
                or 80 + (index * count + move) % 1000,
                y = 570 }
        end
        if playing and index % 4 == 0 then
            step.state = { time_pos = 100 + step.time, percent_pos = (100 + step.time) / 6 }
        end
        if options.style_updates and index % 4 == 0 then
            step.style_variant = index % 8 == 0 and 1 or 2
        end
        if name == 'data-pressure' and step.state then
            local metadata = {}
            local entries = options.data_entries or index % 3 * 16 + 4
            assert(entries >= 1 and entries <= 256 and entries == math.floor(entries), 'data entries out of range')
            for item = 1, entries do
                metadata['field_' .. item] = { value = 'data-' .. item, nested = { index, item } }
            end
            step.state.metadata = metadata
            if options.data_entries then
                local chapters, tracks, ranges = {}, {}, {}
                for item = 1, entries do
                    chapters[item] = { time = item * 600 / entries, title = 'Chapter ' .. item }
                    tracks[item] = { type = 'audio', id = item, title = 'Track ' .. item }
                    ranges[item] = { start = (item - 1) * 600 / entries, ['end'] = item * 600 / entries }
                end
                step.state.chapter_list = chapters
                step.state.track_list = tracks
                step.state.cache_state = { ['seekable-ranges'] = ranges }
            end
        end
        if name == 'environment' and (index == 3 or index == 6) then
            step.environment = { width = index == 3 and 1440 or 1280,
                height = index == 3 and 810 or 720, font = index == 3 and 'sans-serif' or 'Arial' }
            if options.environment_scale then
                step.environment.scale = index == 3 and 1.25 or 1.5
            end
        end
        if name == 'preview' and (index == 4 or index == 8) then
            step.state = { capabilities = { thumbfast = index == 4 and { status = 'unavailable' }
                or { status = 'available', detail = '320x180' } } }
        end
        if name == 'preview' and index == 10 then
            step.moves = { { x = 0, y = 300 } }
        end
        if name == 'preview' and index >= 11 then
            step.time = index == 11 and 0.3 or 0.6 + math.max(0, index - 12) / 240
            if index == 11 or index == 12 then
                step.moves = {}
            end
            if index == 11 or index == 13 then
                step.visible = index == 13
            end
        end
        steps[#steps + 1] = step
    end
    return { schema_version = 1, scene_version = 1, name = name, frames = frames,
        milliseconds = name ~= 'paused-fixed', playing = playing, steps = steps,
        variants = next(options) and { burst_moves = options.burst_moves, data_entries = options.data_entries,
            environment_scale = options.environment_scale, style_updates = options.style_updates } or nil }
end

return M
