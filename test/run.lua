-- Project adapter for the pinned mpv-luatest dependency.
local entry = (arg and arg[0] or 'test/run.lua'):gsub('\\', '/')
local test_directory = entry:match('^(.*)/[^/]+$') or '.'
assert(loadfile(test_directory .. '/dependency.lua'))()
local project_support = assert(loadfile(test_directory .. '/support.lua'))()
local root = project_support.bootstrap(test_directory)

local suite = require 'mpv_luatest.suite'
os.exit(suite.main(arg or {}, {
    verbose = false,
    root = root,
    test_dir = 'test',
    paths = {},
    bootstrap = 'test/bootstrap.lua',
    suite_name = 'elxosc test-suite',
}))
