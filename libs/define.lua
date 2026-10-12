-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- The define protocol (dev/design/HOST.md): `define_start` → `define(scope, code)`
-- (repeatable) → `define_end`.
--
-- Deliberately thin. It owns three things and nothing more:
--   * the phase machine and the message routing;
--   * the scopes — one environment per scope id, reused across payloads;
--   * the three DSL builtins that need that state: `import` / `mod` / `bind`.
--
-- Everything else is injected. `builtins` are the names every scope can read
-- (widget constructors, `print`, ...); modules come from `libs/modules.lua`; and
-- the host's own services are just modules the host publishes — mpv properties
-- and script messages are the `mp` module's business, not the framework's.

local std = require 'elxlibs.std'
local sandbox = require 'libs.sandbox'
local modules_mod = require 'libs.modules'
local bind_mod = require 'widget.bind'

local raise = std.raise
local ModuleRegistry = modules_mod.ModuleRegistry
local BindRegistry = bind_mod.BindRegistry

local M = {}

---@class DefineOptions
---@field builtins table<string, any>? names every scope can read as-is
---@field modules ModuleRegistry? shared module registry
---@field binds BindRegistry? shared bind registry
---@field protected_names table<string, true>? names a chunk may not overwrite

---@alias DefineSessionPhase
--- |>'idle'
--- | 'defining'
--- | 'sealed'

--- One define phase: the scopes it declared, plus the DSL builtins that need to
--- know which scope is currently running.
---@class DefineSession : std.object
---@field modules ModuleRegistry
---@field binds BindRegistry
---@field api table<string, any>
---@field protected_names table<string, true>
---@field phase DefineSessionPhase
---@field current_define string?
---@field current_env table?
---@field on_error fun(scope_id: string, err: any)? called instead of raising when set
---@field _scopes table<string, table>
---@field _defined_scopes table<string, true> scopes with an accepted initial payload
---@overload fun(options: DefineOptions?): self
local DefineSession = std.class.new('DefineSession', {})

function DefineSession:__init(options)
    options = options or {}
    self.modules = options.modules or ModuleRegistry()
    self.binds = options.binds or BindRegistry()
    self.phase = 'idle'
    self.defining_count = 0
    self.current_define = nil
    self.current_env = nil
    self.on_error = nil
    self._scopes = {}
    self._defined_scopes = {}
    self.protected_names = {}
    for name in pairs(options.protected_names or {}) do
        self.protected_names[name] = true
    end
    local api = {}
    for name, value in pairs(options.builtins or {}) do
        api[name] = value
    end
    api['import'] = function(name)
        self:_import(name)
    end
    api['require'] = api['import']
    api['mod'] = function(name, data)
        self:_mod(name, data)
    end
    api['bind'] = function(id, widget, opts)
        self.binds:add(id, widget, opts, self.current_define)
    end
    self.api = api
end

--- The environment of `scope_id`, created on first use and reused afterwards,
--- so a script may split its declaration across several `define` messages.
---@param scope_id string
---@return table env
function DefineSession:env_for(scope_id)
    local env = self._scopes[scope_id]
    if env == nil then
        env = sandbox.new_env(self.api, self.protected_names, scope_id)
        self._scopes[scope_id] = env
    end
    return env
end

---@param name string
function DefineSession:_import(name)
    local env = self.current_env
    if env == nil then
        raise(std.RuntimeError(string.format(
            "import('%s') outside of a define payload", name)))
    end
    self.modules:import_into(name, env, self.current_define --[[@as string]])
end

---@param name string
---@param data table<string, any>?
function DefineSession:_mod(name, data)
    local env = data or self.current_env
    if env == nil then
        raise(std.RuntimeError(string.format("mod('%s') outside of a define payload", name)))
    end
    self.modules:publish(name, env)
end

---@param scope_id string
---@param err any
function DefineSession:_fail(scope_id, err)
    if self.on_error ~= nil then
        self.on_error(scope_id, err)
    else
        raise(err)
    end
end

--- Enter the define phase. Everything a script may declare arrives between here
--- and `define_end`.
function DefineSession:define_start()
    if self.phase == 'sealed' then
        raise(std.RuntimeError('define_start: the session is already sealed'))
    end
    self.phase = 'defining'
    self.defining_count = self.defining_count + 1
end

--- Run one `define` payload against `scope_id`'s environment.
---@param scope_id string
---@param code string
---@return table env
function DefineSession:define(scope_id, code)
    if self.phase ~= 'defining' then
        raise(std.RuntimeError('define(...) outside of the define phase'))
    end
    if type(scope_id) ~= 'string' or scope_id == '' then
        raise(std.ValueError('define(...): the scope id must be a non-empty string'))
    end
    if type(code) ~= 'string' then
        raise(std.TypeError('define(...): the payload must be a string'))
    end
    if self._defined_scopes[scope_id] then
        if self.on_error ~= nil then
            self.on_error(scope_id, std.RuntimeError(
                string.format("define('%s'): duplicate scope ignored", scope_id)))
        end
        return self:env_for(scope_id)
    end
    local env = self:env_for(scope_id)
    local chunk, err = sandbox.load_chunk(code, '@define:' .. scope_id, env)
    if chunk == nil then
        self:_fail(scope_id, string.format("define('%s'): %s", scope_id, tostring(err)))
        return env
    end
    self.current_define, self.current_env = scope_id, env
    local ok, run_err = pcall(chunk)
    self.current_define, self.current_env = nil, nil
    if not ok then
        self:_fail(scope_id, run_err)
    else
        self._defined_scopes[scope_id] = true
    end
    return env
end

--- Seal the tree: no more definitions. The host then applies `self.binds` to the
--- scaffold and mounts it.
function DefineSession:define_end()
    if self.phase == 'idle' then
        raise(std.RuntimeError('define_end: the session is not defining yet'))
    elseif self.phase == 'sealed' then
        raise(std.RuntimeError('define_end: the session already sealed'))
    end
    self.defining_count = self.defining_count - 1
    if self.defining_count <= 0 then
        self.phase = 'sealed'
    end
end

M.ModuleRegistry = ModuleRegistry
M.DefineSession = DefineSession

return M
