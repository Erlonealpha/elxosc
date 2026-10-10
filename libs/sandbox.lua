-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- The two primitives the define protocol needs, and nothing else.
--
-- There is deliberately no sandbox *object* here: the environment is a plain
-- table whose metatable delegates reads to an `api` table and keeps writes
-- local. Which names exist, what `import` does and when a chunk runs all belong
-- to `libs/define.lua` / `libs/modules.lua`. Keeping this file stateless is what
-- stops the define layer from turning into one object that owns everything.

local std = require 'elxlibs.std'

local raise = std.raise

local M = {}

--== load shim =============================================================

--- Compile `code` and force `env` to be its environment.
---
--- LuaJIT is 5.1 based: `load(code, name, 't', env)` only honours the trailing
--- `env` when the build defines LUA52COMPAT; otherwise the argument is silently
--- dropped and the chunk would run against the *real* globals — a sandbox that
--- silently does nothing. So apply the 5.1 escape hatch (`setfenv`) whenever it
--- exists, and otherwise rely on the 5.2 signature.
---@param code string
---@param chunkname string
---@param env table
---@return function? chunk
---@return string? err
function M.load_chunk(code, chunkname, env)
    local chunk, err = load(code, chunkname, 't', env)
    if chunk == nil then
        return nil, err
    end
    local setfenv = rawget(_G, 'setfenv')
    if setfenv ~= nil then
        setfenv(chunk, env)
    end
    return chunk
end

--== environment ===========================================================

--- Build a sandboxed environment.
---
--- `api` is the read side: every name the chunk may use without declaring it.
--- `protected_names` is the write side: names the chunk may not overwrite.
--- Every other assignment lands in the returned table, so it is both the
--- environment and the scope's "module-level variables" — reading `env[k]` from
--- the host side returns exactly what the chunk wrote, and reading an `api` name
--- that the chunk never shadowed falls through.
---@param api table<string, any>
---@param protected_names table<string, true>?
---@param label string? used in the guard's error message
---@return table env
function M.new_env(api, protected_names, label)
    return setmetatable({}, {
        __index = api,
        __newindex = function(env, key, value)
            if protected_names ~= nil and protected_names[key] then
                raise(std.RuntimeError(string.format(
                    "define('%s'): '%s' is provided by elxosc and cannot be overwritten",
                    label or '?', key)))
            end
            rawset(env, key, value)
        end,
    })
end

return M
