-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- The define DSL surface (dev/design/DESIGN.md §4.2).
--
-- Two factories for extension-owned classes:
--   * `new_widget` / `new_state` let a script declare a `StatefulWidget` +
--     `State` pair without touching `std` (see `dev/feat_example.lua`);
--
-- host/builtins.lua exposes these factories; components are imported separately.

---@namespace elxosc
---@using elxosc
---@using elxosc.define

local std = require 'elxlibs.std'
local widget_mod = require 'src.widgets.framework'
local state_mod = require 'src.widgets.state'

---@class mod.define.src.dsl
local M = {}

--- A StatefulWidget subclass a script can complete with create_state.
---@generic T: StatefulWidget
---@[constructor('__init', 'object')]
---@param name `T`
---@param parent StatefulWidget? defaults to StatefulWidget
---@return T
function M.new_widget(name, parent)
    -- The name template belongs to this factory; std receives the runtime string.
    local runtime_name = name --[[@as string]]
    return std.class.new(runtime_name, parent or widget_mod.StatefulWidget) --[[@as T]]
end

--- A State subclass a script can complete with __init / build.
---@generic T: State
---@[constructor('__init', 'object')]
---@param name `T`
---@param parent State? defaults to State
---@return T
function M.new_state(name, parent)
    local runtime_name = name --[[@as string]]
    return std.class.new(runtime_name, parent or state_mod.State) --[[@as T]]
end

return M
