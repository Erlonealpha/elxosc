-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- The module registry behind `mod` / `import` (dev/design/DESIGN_PATH.md §7).
--
-- Two tables, exactly the shape the define DSL expects:
--   * `mods`    — data modules: `import(name)` copies these names into the scope;
--   * `loaders` — installers: `import(name)` runs `loader(env, scope_id)` after
--                 the copy, so a module can install functions that need the
--                 scope itself. mpv's `mp` module installs `on_message` this way;
--                 the framework never learns what `mp` is.
--
-- The registry deals in plain tables only: no sessions, no sandboxes, no
-- widgets. That narrow interface is the point.

local std = require 'elxlibs.std'

local raise = std.raise

local M = {}

---@class ModuleRegistry : std.object
---@field mods table<string, table<string, any>>
---@field loaders table<string, fun(env: table, scope_id: string)>
---@field protected_names table<string, true>
---@overload fun(): ModuleRegistry
local ModuleRegistry = std.class.new('ModuleRegistry')

function ModuleRegistry:__init()
    self.mods = {}
    self.loaders = {}
    self.protected_names = {}
end

--- Register a data module (host side).
---@param name string
---@param data table<string, any>
function ModuleRegistry:add(name, data)
    if type(name) ~= 'string' or name == '' then
        raise(std.ValueError('the module name must be a non-empty string'))
    end
    if type(data) ~= 'table' then
        raise(std.TypeError(string.format("module '%s' must be a table", name)))
    end
    self.mods[name] = data
end

--- Publish `data` under `name` (the `mod` builtin). Refuses to shadow a
--- protected module.
---@param name string
---@param data table<string, any>
function ModuleRegistry:publish(name, data)
    if self.protected_names[name] then
        raise(std.RuntimeError(string.format("mod('%s'): the module is protected", name)))
    end
    self:add(name, data)
end

--- Install the loader that runs on every `import(name)`.
---@param name string
---@param loader fun(env: table, scope_id: string)
function ModuleRegistry:add_loader(name, loader)
    if type(loader) ~= 'function' then
        raise(std.TypeError(string.format("the loader for '%s' must be a function", name)))
    end
    self.loaders[name] = loader
end

--- Forbid `mod(name)` from redefining this module.
---@param name string
function ModuleRegistry:protect(name)
    self.protected_names[name] = true
end

---@param name string
---@return boolean
function ModuleRegistry:is_protected(name)
    return self.protected_names[name] == true
end

---@param name string
---@return boolean
function ModuleRegistry:has(name)
    return self.mods[name] ~= nil or self.loaders[name] ~= nil
end

---@param name string
---@return table<string, any>?
function ModuleRegistry:get(name)
    return self.mods[name]
end

--- Flatten `name` into `env`, then run its loader.
---@param name string
---@param env table<string, any>
---@param scope_id string
function ModuleRegistry:import_into(name, env, scope_id)
    local data = self.mods[name]
    local loader = self.loaders[name]
    if data == nil and loader == nil then
        raise(std.ImportError(string.format(
            "import('%s'): module '%s' has not been published", name, name)))
    end
    if data ~= nil then
        for key, value in pairs(data) do
            env[key] = value
        end
    end
    if loader ~= nil then
        loader(env, scope_id)
    end
end

M.ModuleRegistry = ModuleRegistry

return M
