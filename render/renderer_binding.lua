-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Flutter-style RendererBinding role facade.  PipelineOwner is the per-tree
-- resource; the renderer binding capability belongs to the one framework
-- binding composition.

local M = {}

---@class RendererBindingRole
local RendererBinding = {}

function RendererBinding.ensure_initialized()
    local widgets_binding = require 'widget.binding'
    return widgets_binding.WidgetsBinding.ensure_initialized()
end

function RendererBinding.instance()
    local widgets_binding = require 'widget.binding'
    return widgets_binding.WidgetsBinding.instance()
end

---@param root RenderObject?
---@return RenderOwner
function RendererBinding.create_pipeline_owner(root)
    local pipeline_owner = require 'render.pipeline_owner'
    return pipeline_owner.PipelineOwner(root)
end

M.RendererBinding = RendererBinding

return M
