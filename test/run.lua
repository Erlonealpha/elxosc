-- Entry point for the elxosc standalone test-suite.
--
--   luajit test/run.lua             # everything
--   luajit test/run.lua geometry    # only files whose name matches
--
-- Runs on a bare LuaJIT (mpv is not required). Exit code is 0 when everything
-- passes, 1 otherwise.

local this = (arg and arg[0] or 'test/run.lua'):gsub('\\', '/')
local dir = this:gsub('/[^/]*$', '')
if dir == '' then
    dir = '.'
end

package.path = table.concat({ dir .. '/?.lua', dir .. '/?/init.lua', package.path }, ';')

local support = require('support')
local framework = require('framework')

support.bootstrap(dir)

local filter = (arg and arg[1]) or nil

local files = {
    'test_foundation',
    'test_text',
    'test_scheduler',
    'test_animation',
    'test_layout',
    'test_input',
    'test_widget',
    'test_flutter_runtime',
    'test_button_contract',
    'test_icon',
    'test_bind',
    'test_player_context',
    'test_define',
    'test_dsl',
    'test_host_define',
    'test_host_player_context',
    'test_host_app',
    'test_demo_navigation',
    'test_main_layout',
    'test_overlay',
    'test_navigation',
    'test_ass',
    'test_constraints_examples',
    'test_layering',
}

print('elxosc test-suite (lua ' .. _VERSION .. ', ' .. (jit and jit.version or 'no jit') .. ')')

local ran = 0
for _, name in ipairs(files) do
    if not filter or name:find(filter, 1, true) then
        ran = ran + 1
        local ok, err = pcall(dofile, dir .. '/' .. name .. '.lua')
        if not ok then
            framework.fail(name .. ' crashed: ' .. tostring(err):gsub('\n', ' | '))
        end
    end
end

if ran == 0 then
    framework.fail("no test file matched filter '" .. tostring(filter) .. "'")
end

local all_good = framework.summary()
os.exit(all_good and 0 or 1)
