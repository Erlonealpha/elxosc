-- Static package organization, independent of Define and runtime tree lifecycle.
---@namespace elxosc
---@using elxosc

local std = require 'elxlibs.std'

local ipairs = ipairs
local math = math
local next = next
local rawequal = rawequal
local select = select
local string = string
local tostring = tostring
local type = type

local raise = std.raise

---@alias export.Key string | integer
---@alias export.Exports table<export.Key, any>

---@class export.Package<T>
---@field name    string
---@field exports T

---@class export.Selection
---@field show fun(...: export.Key): export.Selection
---@field hide fun(...: export.Key): export.Selection

---@class export.Context
---@field export  fun(name: string, source: table, append: boolean?): export.Selection
---@field get     fun(name: string): export.Exports
---@field collect fun(): export.Package<export.Exports>[]

---@class export.Source
---@field values export.Exports
---@field keys   table<export.Key, true>?
---@field show   boolean?

---@class export.Declaration
---@field name    string
---@field sources export.Source[]
---@field exports export.Exports?

---@param name string
local function validate_name(name)
    if type(name) ~= 'string' then
        raise(std.TypeError('export package name must be a string'))
    end
    if name == '' or name:find('..', 1, true) or name:sub(1, 1) == '.' or name:sub(-1) == '.' or name:sub(-4) == '.lua' then
        raise(std.ValueError('invalid export package name: ' .. name))
    end
    for segment in name:gmatch('[^.]+') do
        if not segment:match('^[A-Za-z_][A-Za-z0-9_]*$') then
            raise(std.ValueError('invalid export package name: ' .. name))
        end
    end
end

---@param key export.Key
local function validate_key(key)
    if type(key) == 'string' then
        return
    end
    if type(key) == 'number' and key == key and key ~= math.huge and key ~= -math.huge and key == math.floor(key) then
        return
    end
    raise(std.ValueError('export keys must be strings or finite integers'))
end

---@param package export.Declaration
---@return export.Exports
local function resolve(package)
    local values, owners = {}, {}
    for index, source in ipairs(package.sources) do
        for key, value in next, source.values do
            local selected = source.keys == nil or (source.show and source.keys[key] == true)
                or (not source.show and source.keys[key] == nil)
            if selected then
                if owners[key] ~= nil and not rawequal(values[key], value) then
                    raise(
                        std.ValueError(
                            string.format(
                                "package '%s' key '%s' conflicts between sources %d and %d", package.name, tostring(key),
                                owners[key], index
                            )
                        )
                    )
                end
                values[key] = value
                owners[key] = owners[key] or index
            end
        end
    end
    return values
end

--- Each library can organize its own declarations without require-order coupling.
---@return export.Context
local function new_context()
    ---@type table<string, export.Declaration>
    local by_name = {}
    ---@type export.Declaration[]
    local ordered = {}
    local context = {}

    ---@param name   string
    ---@param source table
    ---@param append boolean?
    ---@return export.Selection
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
        ---@type export.Source
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

        ---@param show boolean
        ---@param ...  export.Key
        ---@return export.Selection
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

        ---@param ... export.Key
        ---@return export.Selection
        function selection.show(...)
            return select_keys(true, ...)
        end

        ---@param ... export.Key
        ---@return export.Selection
        function selection.hide(...)
            return select_keys(false, ...)
        end

        return selection
    end

    ---@param name string
    ---@return export.Exports
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

    ---@return export.Package<export.Exports>[]
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

---@class mod.export: export.Context
local M = new_context()
M.new = new_context

return M
