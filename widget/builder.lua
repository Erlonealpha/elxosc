-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Semantic builder contracts and the small runtime validation boundary shared
-- by Widget builds, mounted context builders and initialization Slot builders.
-- The callbacks intentionally remain separate: a Slot builder is allowed to
-- run before mounting, while a context builder requires an active Element.

local std = require 'elxlibs.std'
local widget_mod = require 'widget.widget'

local Widget = widget_mod.Widget
local raise = std.raise

---@class elxosc.widget.builder
local M = {}

---@param name any
---@param fallback string
---@return string
local function operation_name(name, fallback)
    return type(name) == 'string' and name ~= '' and name or fallback
end

---@alias ContextBuilder fun(context: BuildContext): Widget?
---@alias SlotBuilder fun(value: Widget|Widget[]|nil, opts: table<string, any>?): Widget?
---@alias WidgetBuildCallback fun(context: BuildContext): Widget?

---@param callback any
---@param name string
---@return function
function M.validate_callback(callback, name)
    name = operation_name(name, 'Builder')
    if type(callback) ~= 'function' then
        raise(std.TypeError(name .. ' must be a function'))
    end
    return callback
end

---@param context any
---@param name string
---@return BuildContext
function M.validate_context(context, name)
    name = operation_name(name, 'ContextBuilder')
    if type(context) ~= 'table' or type(context.is_active) ~= 'function'
        or not context:is_active() then
        raise(std.RuntimeError(name .. ' requires a mounted BuildContext'))
    end
    return context --[[@as BuildContext]]
end

---@param result any
---@param name string
---@return Widget?
function M.validate_result(result, name)
    name = operation_name(name, 'Builder')
    if result ~= nil and not std.isinstance(result, Widget) then
        raise(std.TypeError(name .. ' must return a Widget or nil'))
    end
    return result --[[@as Widget?]]
end

---@param callback ContextBuilder
---@param context BuildContext
---@param name string
---@return Widget?
function M.call_context(callback, context, name)
    name = operation_name(name, 'ContextBuilder')
    M.validate_callback(callback, name)
    M.validate_context(context, name)
    return M.validate_result(callback(context), name)
end

---@param callback SlotBuilder
---@param value Widget|Widget[]|nil
---@param opts table<string, any>?
---@param name string
---@return Widget?
function M.call_slot(callback, value, opts, name)
    name = operation_name(name, 'SlotBuilder')
    M.validate_callback(callback, name)
    return M.validate_result(callback(value, opts), name)
end

return M
