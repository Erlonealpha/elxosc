-- Regression for LuaJIT's weak-key (non-ephemeron) collection semantics.
local F = require 'framework'
local player_mod = require 'widget.player_context'
local PlayerSnapshot = player_mod.PlayerSnapshot
local PlayerStore = player_mod.PlayerStore

local function collect()
    collectgarbage('collect')
    collectgarbage('collect')
end

F.section('player snapshot: ownership and collection')

F.test('discarded snapshots and nested readonly views are collectible', function()
    local refs = setmetatable({}, { __mode = 'v' })
    local function create()
        local raw = PlayerSnapshot({ tracks = { { id = 7 } } })
        local view = raw:readonly()
        refs[1], refs[2], refs[3], refs[4] = raw, view, view.tracks, view.tracks[1]
    end
    create()
    collect()
    F.eq(next(refs), nil, 'all discarded references disappear')
end)

F.test('retained snapshot view keeps its backing snapshot usable', function()
    local view = PlayerSnapshot({ time_pos = 7, tracks = { { id = 3 } } }):readonly()
    collect()
    F.eq(view.time_pos, 7, 'retained view remains readable')
    F.eq(view.tracks[1].id, 3, 'nested data remains readable')
    F.eq(view:readonly(), view, 'retained view identity is stable')
    F.eq(view:copy({ time_pos = 8 }).time_pos, 8, 'copy works after collection')
end)

F.test('retained nested view keeps its backing data after snapshot release', function()
    local view = assert(PlayerSnapshot({ tracks = { { id = 3 } } }):get('tracks'))
    collect()
    F.eq(view[1].id, 3, 'nested view owns backing data')
    F.eq(view[1], view[1], 'retained child identity is stable')
    F.raises(function()
        view[1].id = 4
    end, 'RuntimeError', 'nested data remains read-only')
end)

F.test('retained raw snapshot can recreate a collected view', function()
    local raw = PlayerSnapshot({ time_pos = 9 })
    local refs = setmetatable({}, { __mode = 'v' })
    local function create()
        refs[1] = raw:readonly()
    end
    create()
    collect()
    F.eq(refs[1], nil, 'unretained view is collectible even with raw snapshot alive')
    F.eq(raw:readonly().time_pos, 9, 'raw snapshot recreates a view')
end)

F.test('live store releases replaced snapshots and readonly views', function()
    local store = PlayerStore({ time_pos = 0 })
    local refs = setmetatable({}, { __mode = 'v' })
    local function replace()
        for index = 1, 100 do
            refs[index] = store:get()
            store:replace({ time_pos = index })
        end
    end
    replace()
    collect()
    F.eq(next(refs), nil, 'replaced store snapshots disappear')
    F.eq(store:get().time_pos, 100, 'current store value stays alive')
end)
