-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- The Flutter-aligned name for the existing single-root RenderOwner.  The
-- compatibility export is intentionally the same class object, not a wrapper.

---@namespace elxosc
---@using elxosc

local render_owner = require 'src.render.render_owner'

local PipelineOwner = render_owner.RenderOwner

---@alias PipelineOwner RenderOwner

---@class mod.src.render.pipeline_owner
local M = {
    PipelineOwner = PipelineOwner,
    RenderOwner = PipelineOwner
}

return M
