-- Project compatibility settings for the external mp stub.
local source = assert(debug.getinfo(1, 'S')).source:gsub('^@', ''):gsub('\\', '/')
local directory = source:match('^(.*)/[^/]+$') or '.'
assert(loadfile(directory .. '/dependency.lua'))()
local mp_stub = require 'mpv_luatest.mp_stub'
mp_stub.configure({ input_section = 'elxosc-input', preserve_mouse = true })
return mp_stub
