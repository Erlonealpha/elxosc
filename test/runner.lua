-- Discovery and selection for the standalone Lua suite. No mpv dependency.
local M = {}

---@param args string[]
---@return table? options
---@return string? error
function M.parse_args(args)
    local options = { verbose = false }
    for _, value in ipairs(args) do
        if value == '-v' then
            options.verbose = true
        elseif value == '-h' or value == '--help' then
            options.help = true
        elseif value:sub(1, 1) == '-' then
            return nil, 'unknown option: ' .. value
        elseif options.filter then
            return nil, 'expected at most one test filter'
        elseif value == '' then
            return nil, 'test filter must not be empty'
        else
            options.filter = value:gsub('\\', '/')
        end
    end
    return options
end

---@param path string
---@return string[]
local function components(path)
    local parts = {}
    for part in path:gsub('\\', '/'):gmatch('[^/]+') do
        parts[#parts + 1] = part:gsub('%.lua$', ''):gsub('^test_?', '')
    end
    return parts
end

--- Each filter component is a literal substring of the corresponding path
--- component. A single component also selects a group at any depth.
---@param path string
---@param filter string?
---@return boolean
function M.matches(path, filter)
    if not filter then
        return true
    end
    local parts, wanted = components(path), components(filter)
    if #wanted == 0 then
        return false
    end
    for start = 1, #parts - #wanted + 1 do
        local matched = true
        for index, needle in ipairs(wanted) do
            local part = parts[start + index - 1]
            if not needle or needle == '' or not part or not part:find(needle, 1, true) then
                matched = false
                break
            end
        end
        if matched then
            return true
        end
    end
    return false
end

---@param path string
---@return boolean
local function is_test_path(path)
    local parts = {}
    for part in path:gmatch('[^/]+') do
        parts[#parts + 1] = part
    end
    for index = 1, #parts - 1 do
        if not parts[index]:match('^test') then
            return false
        end
    end
    return #parts > 0 and parts[#parts]:match('^test_.*%.lua$') ~= nil
end

---@param root string
---@return string[] files relative to root, in deterministic order
function M.discover(root)
    local windows = package.config:sub(1, 1) == '\\'
    local command
    if windows then
        -- cmd's directory stack also resolves relative and UNC checkout paths.
        command = 'pushd "' .. root:gsub('/', '\\') .. '" && cd && dir /b /s /a-d *.lua'
    else
        local quoted = "'" .. root:gsub("'", "'\\''") .. "'"
        command = 'cd ' .. quoted .. ' && pwd && find . -type f -name "*.lua"'
    end
    local handle = io.popen(command)
    if not handle then
        error('cannot discover test files')
    end
    local base = handle:read('*l')
    if not base then
        handle:close()
        error('cannot read test directory: ' .. root)
    end
    base = base:gsub('\\', '/'):gsub('/$', '') .. '/'
    local files = {}
    for line in handle:lines() do
        ---@cast line string
        local path = line:gsub('\\', '/')
        if windows then
            path = path:sub(#base + 1)
        else
            path = path:gsub('^%./', '')
        end
        if is_test_path(path) then
            files[#files + 1] = path
        end
    end
    handle:close()
    table.sort(files)
    return files
end

return M
