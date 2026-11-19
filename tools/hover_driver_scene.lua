-- Versioned deterministic traces; no mp dependency or implicit external media updates.
---@namespace elxosc.tools.hover
local M = {}

M.names = { 'paused-fixed', 'paused-ms', 'playing', 'stationary', 'burst', 'clean',
    'data-pressure', 'environment', 'preview' }

---@param name string
---@param frames integer
---@return table
function M.build(name, frames)
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
        local count = name == 'burst' and 4 or 1
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
        if name == 'data-pressure' and step.state then
            local metadata = {}
            for item = 1, index % 3 * 16 + 4 do
                metadata['field_' .. item] = { value = 'data-' .. item, nested = { index, item } }
            end
            step.state.metadata = metadata
        end
        if name == 'environment' and (index == 3 or index == 6) then
            step.environment = { width = index == 3 and 1440 or 1280,
                height = index == 3 and 810 or 720, font = index == 3 and 'sans-serif' or 'Arial' }
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
        milliseconds = name ~= 'paused-fixed', playing = playing, steps = steps }
end

return M
