-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- The define DSL surface (dev/design/DESIGN.md §4.2).
--
-- Two factories for extension-owned classes:
--   * `new_widget` / `new_state` let a script declare a `StatefulWidget` +
--     `State` pair without touching `std` (see `dev/feat_example.lua`);
--
-- Available builtins are selected explicitly by host/mpv_define.lua.

local std = require 'elxlibs.std'
local widget_mod = require 'widget.widget'
local state_mod = require 'widget.state'

---@class elxosc.libs.dsl
local M = {}

--- A `StatefulWidget` subclass a script can complete with `create_state`.
---@generic T
---@param name string
---@param parent std.class? defaults to `StatefulWidget`
---@return T the new class (EmmyLua cannot model a callable class, so `T` is open)
function M.new_widget(name, parent)
    return std.class.new(name, parent or widget_mod.StatefulWidget)
end

--- A `State` subclass a script can complete with `__init` / `build`.
---@generic T
---@param name string
---@param parent std.class? defaults to `State`
---@return T the new class (see `new_widget`)
function M.new_state(name, parent)
    return std.class.new(name, parent or state_mod.State)
end

return M
