-- Entry point for the elxosc standalone test-suite.
--
--   luajit test/run.lua             # everything
--   luajit test/run.lua player/layout # matching group/file components
--   luajit test/run.lua -v            # include successful tests and sections
--
-- Runs on a bare LuaJIT (mpv is not required). Exit code is 0 when everything
-- passes, 1 otherwise.

local this = (arg and arg[0] or 'test/run.lua'):gsub('\\', '/')
local dir = this:match('^(.*)/[^/]+$') or '.'

package.path = table.concat({ dir .. '/?.lua', dir .. '/?/init.lua', package.path }, ';')

local support = require('support')
local framework = require('framework')
local runner = require('runner')

support.bootstrap(dir)

local options, argument_error = runner.parse_args(arg or {})
if not options then
    framework.fail(tostring(argument_error))
    framework.summary()
    os.exit(1)
end
---@cast options table
if options.help then
    print('Usage: luajit test/run.lua [-v] [group/file filter]')
    os.exit(0)
end
framework.set_verbose(options.verbose)
if options.verbose then
    print('elxosc test-suite (lua ' .. _VERSION .. ', ' .. (jit and jit.version or 'no jit') .. ')')
end

local discovered, files = pcall(runner.discover, dir)
if not discovered then
    framework.fail(tostring(files))
    framework.summary()
    os.exit(1)
end
---@cast files string[]

local ran = 0
for _, name in ipairs(files) do
    if runner.matches(name, options.filter) then
        ran = ran + 1
        framework.file(name)
        local ok, err = pcall(dofile, dir .. '/' .. name)
        if not ok then
            framework.fail(name .. ' crashed: ' .. tostring(err):gsub('\n', ' | '))
        end
    end
end

if ran == 0 then
    framework.fail("no test file matched filter '" .. tostring(options.filter) .. "'")
end

local all_good = framework.summary()
os.exit(all_good and 0 or 1)
