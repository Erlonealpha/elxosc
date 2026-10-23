-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Instance-scoped renderer binding for a single PipelineOwner and Canvas.

local std = require 'elxlibs.std'
local binding_base = require 'foundation.binding_base'
local pipeline_owner = require 'render.pipeline_owner'

local BindingBase = binding_base.BindingBase
local PipelineOwner = pipeline_owner.PipelineOwner

local M = {}

---@alias PipelineOwner RenderOwner

---@class RendererBinding : std.object
---@field pipeline_owner RenderOwner
---@field canvas Canvas?
---@overload fun(pipeline_owner: RenderOwner?, canvas: Canvas?): self
local RendererBinding = std.class.new('RendererBinding', { BindingBase })

function RendererBinding:__init(owner, canvas)
    ---@diagnostic disable-next-line: param-type-mismatch, generic-constraint-mismatch
    std.super(RendererBinding, self, BindingBase).__init(self)
    self.pipeline_owner = owner or PipelineOwner()
    self.canvas = canvas
end

---@param canvas Canvas
function RendererBinding:draw_frame(canvas)
    self:assert_alive()
    canvas = canvas or self.canvas
    if canvas == nil then
        return
    end
    self.pipeline_owner:layout()
    self.pipeline_owner:paint(canvas)
end

function RendererBinding:dispose()
    if self._disposed then
        return false
    end
    self.pipeline_owner:set_root(nil, false)
    self.pipeline_owner.on_dirty = nil
    self.pipeline_owner = nil
    self.canvas = nil
    return BindingBase.dispose(self)
end

M.RendererBinding = RendererBinding

return M
