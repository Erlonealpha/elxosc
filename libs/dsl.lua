-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- The define DSL surface (DESIGN.md §4.2).
--
-- Two factories and one default name table:
--   * `new_widget` / `new_state` let a script declare a `StatefulWidget` +
--     `State` pair without touching `std` (see `dev/feat_example.lua`);
--   * `builtins()` is the set of names every scope may read as-is — the widget
--     library plus the value types those constructors take.
--
-- mpv-free on purpose: a host merges its own names (`print`, `mp`, ...) on top
-- of `builtins()` and hands the result to `DefineSession`.

local std = require 'elxlibs.std'
local geometry = require 'foundation.geometry'
local color = require 'foundation.color'
local paint = require 'painting.paint'
local text_style = require 'text.text_style'
local widget_mod = require 'widget.widget'
local state_mod = require 'widget.state'

---@class elxdsl
local M = {}

--- A `StatefulWidget` subclass a script can complete with `create_state`.
---@generic T
---@param name string
---@param parent std.Class? defaults to `StatefulWidget`
---@return T the new class (EmmyLua cannot model a callable class, so `T` is open)
function M.new_widget(name, parent)
    return std.class.new(name, { parent or widget_mod.StatefulWidget })
end

--- A `State` subclass a script can complete with `__init` / `build`.
---@generic T
---@param name string
---@param parent std.Class? defaults to `State`
---@return T the new class (see `new_widget`)
function M.new_state(name, parent)
    return std.class.new(name, { parent or state_mod.State })
end

--- The names a scope can use without declaring them.
---@return table<string, any>
function M.builtins()
    local out = {}
    local sources = {
        require 'widget',
        {
            Offset = geometry.Offset,
            Size = geometry.Size,
            Rect = geometry.Rect,
            EdgeInsets = geometry.EdgeInsets,
            Color = color.Color,
            Paint = paint.Paint,
            TextStyle = text_style.TextStyle,
        },
    }
    for _, source in ipairs(sources) do
        for name, value in pairs(source) do
            out[name] = value
        end
    end
    out.new_widget = M.new_widget
    out.new_state = M.new_state
    return out
end

return M
