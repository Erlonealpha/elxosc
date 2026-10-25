-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Host-independent, explicitly injected player/window actions.

local std = require 'elxlibs.std'
local widget_mod = require 'widget.widget'

local raise = std.raise
local InheritedWidget = widget_mod.InheritedWidget

local M = {}

---@class _HostActionsOptions
---@field play_pause fun()?
---@field seek fun(seconds: number)?
---@field toggle_fullscreen fun()?
---@field minimize fun()?
---@field close fun()?

---@class HostActions : std.object
---@field private _callbacks table<string, function>
---@overload fun(options?: _HostActionsOptions): self
local HostActions = std.class.new('HostActions', {})

local ACTIONS = { 'play_pause', 'seek', 'toggle_fullscreen', 'minimize', 'close' }

function HostActions:__init(options)
    options = options or {}
    if type(options) ~= 'table' then
        raise(std.TypeError('HostActions expects an options table'))
    end
    self._callbacks = {}
    for _, name in ipairs(ACTIONS) do
        local callback = options[name]
        if callback ~= nil and type(callback) ~= 'function' then
            raise(std.TypeError('HostActions.' .. name .. ' must be a function'))
        end
        self._callbacks[name] = callback
    end
end

---@param name string
---@param ... any
---@return any
function HostActions:call(name, ...)
    local callback = self._callbacks[name]
    if callback == nil then
        return nil
    end
    return callback(...)
end

function HostActions:play_pause()
    return self:call('play_pause')
end

---@param seconds number
function HostActions:seek(seconds)
    return self:call('seek', seconds)
end

function HostActions:toggle_fullscreen()
    return self:call('toggle_fullscreen')
end

function HostActions:minimize()
    return self:call('minimize')
end

function HostActions:close()
    return self:call('close')
end

---@class _HostActionsScopeOptions
---@field actions HostActions
---@field child Widget?
---@field key any?

---@class HostActionsScope : InheritedWidget
---@field actions HostActions
---@field child Widget?
---@overload fun(options: _HostActionsScopeOptions): self
local HostActionsScope = std.class.new('HostActionsScope', { InheritedWidget })
local HostActionsScopeClass = HostActionsScope --[[@as std.Class]]

function HostActionsScope:__init(options)
    if type(options) ~= 'table' then
        raise(std.TypeError('HostActionsScope expects an options table'))
    end
    self.key = options.key
    self.actions = options.actions or HostActions()
    self.child = options.child
    if not std.isinstance(self.actions, HostActions) then
        raise(std.TypeError('HostActionsScope.actions must be HostActions'))
    end
end

function HostActionsScope:update_should_notify(old_widget)
    return self.actions ~= old_widget.actions
end

---@param context BuildContext
---@return HostActionsScope
function HostActionsScope.of(context)
    if context == nil or type(context.depend_on_inherited_widget_of_exact_type) ~= 'function' then
        raise(std.TypeError('HostActions lookup expects a BuildContext'))
    end
    local value = context:depend_on_inherited_widget_of_exact_type(HostActionsScopeClass)
    if value == nil then
        raise(std.RuntimeError('no HostActionsScope ancestor was found'))
    end
    return value --[[@as HostActionsScope]]
end

---@param context BuildContext
---@return HostActions?
function HostActions.maybe_of(context)
    if context == nil or type(context.depend_on_inherited_widget_of_exact_type) ~= 'function' then
        raise(std.TypeError('HostActions lookup expects a BuildContext'))
    end
    local scope = context:depend_on_inherited_widget_of_exact_type(HostActionsScopeClass)
    return scope and scope.actions or nil --[[@as HostActions?]]
end

M.HostActions = HostActions
M.HostActionsScope = HostActionsScope

return M
