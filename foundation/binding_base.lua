-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Host-independent base for instance-scoped framework bindings.  Unlike
-- Flutter's process-wide convenience accessors, an elxosc binding owns only
-- the resources passed to it by its caller.

local std = require 'elxlibs.std'

local M = {}
local raise = std.raise

local BindingBase = std.class.new('BindingBase', {})

function BindingBase:__init()
    self._initialized = true
    self._disposed = false
    self.phase = 'idle'
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
    return true
end

M.BindingBase = BindingBase

return M
