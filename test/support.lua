-- Shared bootstrap for the elxosc standalone test-suite.
--
-- The suite runs on a bare LuaJIT (no mpv needed). The elxosc modules are
-- loaded straight from this repository by their bare name (e.g.
-- `require 'foundation.color'`, no `elxosc.` prefix) and `elxlibs.*` from the
-- sibling `elxlib` checkout, so the real elxlib `init.lua` (ffi / DLL-path
-- setup) never runs.

local S = {}

--- Make the elxosc modules (bare names) and `elxlibs.*` require-able.
---@param test_dir string directory that holds this test file
---@return string osc_root the resolved elxosc directory
function S.bootstrap(test_dir)
    local osc_root, scripts_root
    if test_dir:match('^%a:') or test_dir:sub(1, 1) == '/' then
        -- absolute: <scripts>/elxosc/test
        osc_root = test_dir:gsub('/test$', '')
        scripts_root = osc_root:gsub('/[^/]*$', '')
    else
        -- relative: "<something>/test", or a bare "test" when started from elxosc
        local prefix = test_dir:match('^(.*)/test$')
        if prefix then
            osc_root = prefix
            scripts_root = prefix .. '/..'
        else
            osc_root = '.'
            scripts_root = '..'
        end
    end

    package.path = table.concat({
        test_dir .. '/?.lua',
        osc_root .. '/?.lua',
        osc_root .. '/?/init.lua',
        scripts_root .. '/?.lua',
        scripts_root .. '/?/init.lua',
        scripts_root .. '/elxlib/?.lua',
        scripts_root .. '/elxlib/?/init.lua',
        package.path,
    }, ';')

    -- normally defined by elxlib's init.lua
    _G.debug_msg = _G.debug_msg or function() end
    return osc_root
end

return S
