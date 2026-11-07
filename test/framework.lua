-- Compatibility import for existing project tests; implementation is external.
local source = assert(debug.getinfo(1, 'S')).source:gsub('^@', ''):gsub('\\', '/')
local directory = source:match('^(.*)/[^/]+$') or '.'
assert(loadfile(directory .. '/dependency.lua'))()
local framework = require 'mpv_luatest.framework'
return framework
