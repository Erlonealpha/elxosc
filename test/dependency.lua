-- Locate the pinned test-only dependency next to this project's test directory.
local source = assert(debug.getinfo(1, 'S')).source:gsub('^@', ''):gsub('\\', '/')
local test_directory = source:match('^(.*)/[^/]+$') or '.'
local dependency_root = test_directory .. '/../mpv-luatest'
local entry = io.open(dependency_root .. '/src/mpv_luatest/suite.lua', 'r')
if not entry then
    error('mpv-luatest is missing; run git submodule update --init --recursive')
end
entry:close()
package.path = dependency_root .. '/src/?.lua;' .. dependency_root
    .. '/src/?/init.lua;' .. package.path

return { root = dependency_root }
