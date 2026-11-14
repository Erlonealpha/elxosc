-- Static package organization, independent of Define and runtime tree lifecycle.
local std = require 'elxlibs.std'
local raise = std.raise

---@alias elxosc.export.Key string | integer
---@alias elxosc.export.Exports table<elxosc.export.Key, any>

---@class elxosc.export.Package<T>
---@field name string
---@field exports T

---@class elxosc.export.Selection
---@field show fun(...: elxosc.export.Key): elxosc.export.Selection
---@field hide fun(...: elxosc.export.Key): elxosc.export.Selection

---@class elxosc.export.Context
---@field export fun(name: string, source: table, append: boolean?): elxosc.export.Selection
---@field get fun(name: string): elxosc.export.Exports
---@field collect fun(): elxosc.export.Package<elxosc.export.Exports>[]

---@class elxosc.export.Source
---@field values elxosc.export.Exports
---@field keys table<elxosc.export.Key, true>?
---@field show boolean?

---@class elxosc.export.Declaration
---@field name string
---@field sources elxosc.export.Source[]
---@field exports elxosc.export.Exports?

local function validate_name(name)
    if type(name) ~= 'string' then
        raise(std.TypeError('export package name must be a string'))
    end
    if name == '' or name:find('..', 1, true) or name:sub(1, 1) == '.'
        or name:sub(-1) == '.' or name:sub(-4) == '.lua' then
        raise(std.ValueError('invalid export package name: ' .. name))
    end
    for segment in name:gmatch('[^.]+') do
        if not segment:match('^[A-Za-z_][A-Za-z0-9_]*$') then
            raise(std.ValueError('invalid export package name: ' .. name))
        end
    end
end

local function validate_key(key)
    if type(key) == 'string' then
        return
    end
    if type(key) == 'number' and key == key and key ~= math.huge
        and key ~= -math.huge and key == math.floor(key) then
        return
    end
    raise(std.ValueError('export keys must be strings or finite integers'))
end

---@param package elxosc.export.Declaration
---@return elxosc.export.Exports
local function resolve(package)
    local values, owners = {}, {}
    for index, source in ipairs(package.sources) do
        for key, value in next, source.values do
            local selected = source.keys == nil
                or (source.show and source.keys[key] == true)
                or (not source.show and source.keys[key] == nil)
            if selected then
                if owners[key] ~= nil and not rawequal(values[key], value) then
                    raise(std.ValueError(string.format(
                        "package '%s' key '%s' conflicts between sources %d and %d",
                        package.name, tostring(key), owners[key], index)))
                end
                values[key] = value
                owners[key] = owners[key] or index
            end
        end
    end
    return values
end

--- Each library can organize its own declarations without require-order coupling.
---@return elxosc.export.Context
local function new_context()
    ---@type table<string, elxosc.export.Declaration>
    local by_name = {}
    ---@type elxosc.export.Declaration[]
    local ordered = {}
    local context = {}

    function context.export(name, source, append)
        validate_name(name)
        if type(source) ~= 'table' then
            raise(std.TypeError('export source must be a table'))
        end
        if append ~= nil and type(append) ~= 'boolean' then
            raise(std.TypeError('export append must be a boolean'))
        end
        local package = by_name[name]
        if package and package.exports ~= nil then
            raise(std.RuntimeError("package '" .. name .. "' is already published"))
        end
        ---@type elxosc.export.Source
        local declaration = { values = {} }
        for key, value in next, source do
            validate_key(key)
            declaration.values[key] = value
        end
        if package == nil then
            package = { name = name, sources = {} }
            by_name[name] = package
            ordered[#ordered + 1] = package
        end
        if not append then
            package.sources = {}
        end
        package.sources[#package.sources + 1] = declaration
        local sources = package.sources
        local selection = {}

        local function select_keys(show, ...)
            local current_sources = package.sources
            if package.exports ~= nil or current_sources ~= sources then
                raise(std.RuntimeError("package '" .. name .. "' is published or its source was replaced"))
            end
            if declaration.keys ~= nil then
                raise(std.RuntimeError('an export source can only be selected once'))
            end
            local keys = {}
            for index = 1, select('#', ...) do
                local key = select(index, ...)
                validate_key(key)
                if keys[key] ~= nil or declaration.values[key] == nil then
                    raise(std.ValueError("duplicate or unknown export key '" .. tostring(key) .. "'"))
                end
                keys[key] = true
            end
            declaration.keys = keys
            declaration.show = show
            return selection
        end

        function selection.show(...)
            return select_keys(true, ...)
        end

        function selection.hide(...)
            return select_keys(false, ...)
        end

        return selection
    end

    function context.get(name)
        validate_name(name)
        local package = by_name[name]
        if package == nil then
            raise(std.ImportError("unknown export package '" .. name .. "'"))
        end
        if package.exports == nil then
            package.exports = resolve(package)
            package.sources = {}
        end
        return package.exports
    end

    function context.collect()
        -- Validate every pending package before publishing any of them.
        local pending = {}
        for index, package in ipairs(ordered) do
            if package.exports == nil then
                pending[index] = resolve(package)
            end
        end
        local packages = {}
        for index, package in ipairs(ordered) do
            if package.exports == nil then
                package.exports = pending[index]
                package.sources = {}
            end
            packages[index] = { name = package.name, exports = package.exports }
        end
        return packages
    end

    return context
end

---@class elxosc.mod.export : elxosc.export.Context
local M = new_context()
M.new = new_context

return M
