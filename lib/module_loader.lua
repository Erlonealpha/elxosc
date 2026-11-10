-- Canonical source-module loading shared by mpv and standalone consumers.
---@class elxosc.module_loader
local M = {}

---@param root string repository root
function M.install(root)
    root = root:gsub('\\', '/'):gsub('/+$', '')
    package.path = root .. '/lib/?.lua;' .. root .. '/lib/?/init.lua;'
        .. root .. '/?.lua;' .. root .. '/?/init.lua;' .. package.path
    if package.loaded['elxosc.source_searcher'] then
        return
    end
    local function source_searcher(name)
        local canonical = name:gsub('%.lua$', ''):gsub('/', '.')
        if not canonical:match('^src%.') then
            return
        end
        canonical = canonical:gsub('%.init$', '')
        if not canonical:match('^src%.[%w_]+[%.%w_]*$') or canonical:find('%.%.') then
            return '\n\tinvalid elxosc source module name'
        end
        if canonical ~= name then
            return function()
                return require(canonical)
            end
        end
        local relative = canonical:gsub('%.', '/')
        local chunk = loadfile(root .. '/lib/' .. relative .. '.lua')
            or loadfile(root .. '/lib/' .. relative .. '/init.lua')
        if chunk then
            return chunk
        end
        return '\n\tno elxosc source module ' .. canonical
    end
    table.insert(package.loaders, 2, source_searcher)
    package.loaded['elxosc.source_searcher'] = true
end

return M
