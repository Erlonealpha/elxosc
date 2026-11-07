-- elxosc setup for mpv-luatest's standalone CLI.
local _, test_directory = ...
local project_support = assert(loadfile(test_directory .. '/support.lua'))()
project_support.bootstrap(test_directory)

local mp_stub = require 'mpv_luatest.mp_stub'
-- The unchanged host tests rely on their old stub retaining mouse position
-- across resets. New projects get a cleared mouse by default.
mp_stub.configure({ input_section = 'elxosc-input', preserve_mouse = true })
