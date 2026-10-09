-- Layering guard: the framework layers must stay host agnostic.
--
-- The whole point of elxosc is that foundation / painting / text / scheduler /
-- layout / render / widget / backends / libs stay mpv-free (so a mpv.net backend
-- can reuse them verbatim). This test fails the suite if one of those starts
-- requiring mpv. Everything else (host/, entry points, tests, examples/design
-- sketches) is free to use mpv.

-- See the note in test_widget.lua: the `std.class` / optional-ownership
-- diagnostics are disabled across the suite.
---@diagnostic disable: undefined-field, inject-field, need-check-nil, generic-constraint-mismatch, preferred-local-alias, unused

local F = require('framework')

local self_path = debug.getinfo(1, 'S').source:gsub('^@', ''):gsub('\\', '/')
local is_windows = package.config:sub(1, 1) == '\\'

-- Repository root: the directory that holds `host/`, `render/`, ... .
local root
do
    local dir = self_path:gsub('/[^/]*$', '')
    root = dir:match('/test$') and dir:gsub('/test$', '') or '.'
end

---@return string[] absolute_paths
local function list_lua_files()
    local command
    if is_windows then
        command = 'dir /b /s "' .. root:gsub('/', '\\') .. '\\*.lua"'
    else
        command = 'find "' .. root .. '" -name "*.lua"'
    end
    local files = {}
    local handle = io.popen(command)
    if not handle then
        return files
    end
    for line in handle:lines() do
        if line ~= '' then
            files[#files + 1] = line:gsub('\\', '/')
        end
    end
    handle:close()
    return files
end

---@param path string
---@return string?
local function read_file(path)
    local handle = io.open(path, 'r')
    if not handle then
        return nil
    end
    local content = handle:read('*a')
    handle:close()
    return content
end

--- Framework directories that must never reach for mpv.
---@param path string
---@return boolean
local function is_framework(path)
    return path:match('/foundation/') ~= nil
        or path:match('/painting/') ~= nil
        or path:match('/text/') ~= nil
        or path:match('/scheduler/') ~= nil
        or path:match('/layout/') ~= nil
        or path:match('/render/') ~= nil
        or path:match('/widget/') ~= nil
        or path:match('/backends/') ~= nil
        or path:match('/libs/') ~= nil
end

--- Matches `require 'mp'`, `require("mp.utils")`, `require 'mp.assdraw'` ...
local MP_REQUIRE = "require%s*%(?%s*[\"']mp[%.\"']"

---@param content string
---@return string?
local function first_mp_require(content)
    for line in (content .. '\n'):gmatch('([^\n]*)\n') do
        local code = line:gsub('%-%-.*$', '')
        if code:find(MP_REQUIRE) then
            return (line:gsub('^%s+', ''):gsub('%s+$', ''))
        end
    end
end

F.section('layering: the framework stays mpv-free')

local files = list_lua_files()

F.test('scans the whole tree', function()
    F.ok(#files >= 20, 'scanned ' .. #files .. ' lua files')
end)

F.test('no framework module requires mp', function()
    local offenders = {}
    for _, path in ipairs(files) do
        if is_framework(path) then
            local content = read_file(path)
            local line = content and first_mp_require(content)
            if line then
                offenders[#offenders + 1] = path .. ' -> ' .. line
            end
        end
    end
    F.eq(#offenders, 0, 'framework modules reaching for mpv: ' .. table.concat(offenders, ' ; '))
end)

F.test('the host layer really does use mp (sanity)', function()
    local host_file
    for _, path in ipairs(files) do
        if path:match('/host/mpv_app%.lua$') then
            host_file = path
        end
    end
    local quote = string.char(39)
    local needle = 'require ' .. quote .. 'mp' .. quote
    local content = host_file and read_file(host_file)
    F.ok(content ~= nil and content:find(needle, 1, true) ~= nil,
        'host/mpv_app.lua requires mp')
end)
