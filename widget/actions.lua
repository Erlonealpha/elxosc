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
---@field replay fun()?
---@field seek fun(seconds: number)?
---@field seek_to fun(seconds: number)? absolute position in seconds
---@field playlist_prev fun()?
---@field playlist_next fun()?
---@field chapter_prev fun()?
---@field chapter_next fun()?
---@field cycle_audio fun()?
---@field cycle_subtitle fun()?
---@field toggle_mute fun()?
---@field set_volume fun(volume: number)?
---@field toggle_fullscreen fun()?
---@field toggle_maximized fun()?
---@field minimize fun()?
---@field toggle_ontop fun()?
---@field screenshot fun(flag: string?)?
---@field show_message fun(message: string, duration: number?)?
---@field close fun()?

---@class HostActions : std.object
---@field private _callbacks table<string, function>
---@overload fun(options?: _HostActionsOptions): self
local HostActions = std.class.new('HostActions', {})

local ACTIONS = {
    'play_pause', 'replay', 'seek', 'seek_to',
    'playlist_prev', 'playlist_next', 'chapter_prev', 'chapter_next',
    'cycle_audio', 'cycle_subtitle', 'toggle_mute', 'set_volume',
    'toggle_fullscreen', 'toggle_maximized', 'minimize', 'toggle_ontop',
    'screenshot', 'show_message', 'close',
}

local function require_finite(name, value)
    if type(value) ~= 'number' or value ~= value
        or value == math.huge or value == -math.huge then
        raise(std.ValueError('HostActions.' .. name .. ' expects a finite number'))
    end
    return value
end

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

---@param name string
---@return boolean
function HostActions:has(name)
    return type(name) == 'string' and self._callbacks[name] ~= nil
end

function HostActions:play_pause()
    return self:call('play_pause')
end

function HostActions:replay()
    return self:call('replay')
end

---@param seconds number
function HostActions:seek(seconds)
    return self:call('seek', require_finite('seek', seconds))
end

---@param seconds number
function HostActions:seek_to(seconds)
    return self:call('seek_to', require_finite('seek_to', seconds))
end

function HostActions:playlist_prev()
    return self:call('playlist_prev')
end

function HostActions:playlist_next()
    return self:call('playlist_next')
end

function HostActions:chapter_prev()
    return self:call('chapter_prev')
end

function HostActions:chapter_next()
    return self:call('chapter_next')
end

function HostActions:cycle_audio()
    return self:call('cycle_audio')
end

function HostActions:cycle_subtitle()
    return self:call('cycle_subtitle')
end

function HostActions:toggle_mute()
    return self:call('toggle_mute')
end

---@param volume number
function HostActions:set_volume(volume)
    return self:call('set_volume', require_finite('set_volume', volume))
end

function HostActions:toggle_fullscreen()
    return self:call('toggle_fullscreen')
end

function HostActions:toggle_maximized()
    return self:call('toggle_maximized')
end

function HostActions:minimize()
    return self:call('minimize')
end

function HostActions:toggle_ontop()
    return self:call('toggle_ontop')
end

---@param flag string?
function HostActions:screenshot(flag)
    if flag ~= nil and type(flag) ~= 'string' then
        raise(std.TypeError('HostActions.screenshot flag must be a string'))
    end
    return self:call('screenshot', flag)
end

---@param message string
---@param duration number?
function HostActions:show_message(message, duration)
    if type(message) ~= 'string' then
        raise(std.TypeError('HostActions.show_message message must be a string'))
    end
    if duration ~= nil then
        duration = require_finite('show_message duration', duration)
        if duration < 0 then
            raise(std.ValueError('HostActions.show_message duration must be non-negative'))
        end
    end
    return self:call('show_message', message, duration)
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
