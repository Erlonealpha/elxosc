-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Define-time contribution entry point.
--
-- The old BindRegistry wrote directly into caller-owned Widgets.  R1 replaces
-- that mutation path with a sealed ContributionRegistry and a fresh-description
-- CompositionAssembler.  `bind()` is intentionally only a small DSL helper;
-- it does not know about Element, State, BuildContext or the host.

local slot_mod = require 'widget.slot'

local M = {}

M.SlotSpec = slot_mod.SlotSpec
M.SlotWrap = slot_mod.SlotWrap
M.Contribution = slot_mod.Contribution
M.ContributionRegistry = slot_mod.ContributionRegistry
M.CompositionAssembler = slot_mod.CompositionAssembler

---@param registry ContributionRegistry
---@param slot_id string
---@param widget Widget
---@param opts table<string, any>?
---@param scope_id string?
function M.bind(registry, slot_id, widget, opts, scope_id)
    return registry:add(slot_id, widget, opts, scope_id)
end

return M
