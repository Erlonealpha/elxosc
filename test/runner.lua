-- Compatibility import for the shared test discovery and CLI implementation.
local source = assert(debug.getinfo(1, 'S')).source:gsub('^@', ''):gsub('\\', '/')
local directory = source:match('^(.*)/[^/]+$') or '.'
assert(loadfile(directory .. '/dependency.lua'))()
local runner = require 'mpv_luatest.runner'
return runner
