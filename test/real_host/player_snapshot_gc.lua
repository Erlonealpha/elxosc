-- Exercise view ownership with the host's actual LuaJIT collector.
local mp = require 'mp'
local scripts = mp.command_native({ 'expand-path', '~~/scripts' })
package.path = package.path .. ';' .. scripts .. '/?.lua;' .. scripts .. '/?/init.lua'
    .. ';' .. scripts .. '/elxosc/?.lua;' .. scripts .. '/elxosc/?/init.lua'
package.loaded.elxlib = assert(loadfile(scripts .. '/elxlib/init.lua'))('elxlib')
local player_mod = require 'widget.player_context'
local refs = setmetatable({}, { __mode = 'v' })
local store = player_mod.PlayerStore({ time_pos = 0 })

local function create()
    for index = 1, 200 do
        local raw = player_mod.PlayerSnapshot({ time_pos = index, tracks = { { id = index } } })
        local view = raw:readonly()
        refs[index * 4], refs[index * 4 + 1] = raw, view
        refs[index * 4 + 2], refs[index * 4 + 3] = view.tracks, view.tracks[1]
        store:replace(raw)
    end
    store:replace({ time_pos = 201 })
end
create()
local retained = player_mod.PlayerSnapshot({ tracks = { { id = 7 } } }):readonly()
collectgarbage('collect')
collectgarbage('collect')
local survivors = 0
for _ in pairs(refs) do
    survivors = survivors + 1
end
mp.set_property_native('user-data/elxosc-snapshot-gc', {
    survivors = survivors, retained_id = retained.tracks[1].id,
    store_time = store:get().time_pos, runtime = jit.version,
})
