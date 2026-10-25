-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Host-independent base for the process-scoped framework binding.  Like
-- Flutter's BindingBase, the concrete binding composition is initialized once
-- per Lua runtime.  Per-tree BuildOwner/PipelineOwner state belongs to owner
-- scopes created by that binding, not to another binding instance.

local std = require 'elxlibs.std'

local M = {}
local raise = std.raise
local current_binding

local BindingBase = std.class.new('BindingBase', {})

function BindingBase:__init()
    self._initialized = true
    self._disposed = false
    self.phase = 'idle'
end

--- Claim the one concrete binding composition for this Lua runtime.
---@return self
function BindingBase:claim_instance()
    if current_binding ~= nil and current_binding ~= self then
        error('a framework BindingBase instance is already initialized', 2)
    end
    current_binding = self
    return self
end

---@return BindingBase?
function BindingBase.current_instance()
    return current_binding
end

---@param factory fun(): BindingBase
---@return BindingBase
function BindingBase.ensure_initialized(factory)
    if current_binding ~= nil then
        return current_binding --[[@as BindingBase]]
    end
    local binding = factory()
    if current_binding ~= binding then
        binding:claim_instance()
    end
    return binding
end

---@return boolean
function BindingBase:is_initialized()
    return self._initialized and not self._disposed
end

function BindingBase:assert_alive()
    if not self:is_initialized() then
        raise(std.RuntimeError('binding is disposed'))
    end
end

---@param phase string
function BindingBase:set_phase(phase)
    self:assert_alive()
    self.phase = phase
end

---@return boolean
function BindingBase:dispose()
    if self._disposed then
        return false
    end
    self._disposed = true
    self.phase = 'disposed'
    if current_binding == self then
        current_binding = nil
    end
    return true
end

M.BindingBase = BindingBase

return M
