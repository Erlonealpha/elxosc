-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Minimal painting binding.  Shared image caches and engine resources are
-- intentionally outside this first runtime slice.

local std = require 'elxlibs.std'
local binding_base = require 'foundation.binding_base'

local BindingBase = binding_base.BindingBase

local M = {}

---@class PaintingBinding : std.object
---@field canvas Canvas?
---@overload fun(canvas: Canvas?): self
local PaintingBinding = std.class.new('PaintingBinding', { BindingBase })

function PaintingBinding:__init(canvas)
    ---@diagnostic disable-next-line: param-type-mismatch, generic-constraint-mismatch
    std.super(PaintingBinding, self, BindingBase).__init(self)
    self.canvas = canvas
end

function PaintingBinding:dispose()
    if self._disposed then
        return false
    end
    self.canvas = nil
    return BindingBase.dispose(self)
end

M.PaintingBinding = PaintingBinding

return M
