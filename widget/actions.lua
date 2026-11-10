-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Host-independent, explicitly injected player/window actions.

local std = require 'elxlibs.std'
local widget_mod = require 'widget.widget'

local raise = std.raise
local InheritedWidget = widget_mod.InheritedWidget

---@class elxosc.widget.actions
local M = {}

---@class _HostActionsOptions
---@field play_pause fun()?
---@field replay fun()?
---@field seek fun(seconds: number, mode: 'relative'|'absolute')?
---@field seek_to fun(seconds: number, mode: 'keyframe'|'exact')? absolute position in seconds
---@field set_pause fun(paused: boolean)?
---@field thumbfast_request fun(seconds: number, x: number, y: number)?
---@field thumbfast_clear fun()?
---@field open_url fun(url: string)?
---@field playlist_prev fun()?
---@field playlist_next fun()?
---@field select_playlist fun()?
---@field chapter_prev fun()?
---@field chapter_next fun()?
---@field set_chapter fun(index: number)?
---@field select_chapter fun()?
---@field set_track fun(kind: 'audio'|'sub', id: number|string)?
---@field clear_audio_filter fun()?
---@field select_audio_track fun()?
---@field load_audio_track fun()?
---@field clear_secondary_subtitle fun()?
---@field select_subtitle fun()?
---@field cycle_audio_reverse fun()?
---@field cycle_subtitle_reverse fun()?
---@field cycle_audio fun()?
---@field cycle_subtitle fun()?
---@field toggle_mute fun()?
---@field set_volume fun(volume: number)?
---@field select_audio_device fun()?
---@field frame_step fun()?
---@field frame_back_step fun()?
---@field toggle_fullscreen fun()?
---@field toggle_maximized fun()?
---@field minimize fun()?
---@field toggle_ontop fun()?
---@field toggle_loop fun()?
---@field screenshot fun(flag: string?)?
---@field show_stats fun()?
---@field download fun(url: string)?
---@field show_message fun(message: string, duration: number?)?
---@field close fun()?
---@field playlist_shuffle fun()?
---@field playlist_first fun()?
---@field playlist_last fun()?

---@class HostActions : std.object
---@field private _callbacks table<string, function>
---@overload fun(options?: _HostActionsOptions): self
local HostActions = std.class.new('HostActions')

local ACTIONS = {
    'play_pause', 'replay', 'seek', 'seek_to', 'set_pause',
    'thumbfast_request', 'thumbfast_clear', 'open_url',
    'playlist_prev', 'playlist_next', 'select_playlist', 'chapter_prev', 'chapter_next',
    'set_chapter', 'select_chapter', 'set_track', 'clear_audio_filter',
    'select_audio_track', 'load_audio_track', 'clear_secondary_subtitle', 'select_subtitle',
    'cycle_audio', 'cycle_audio_reverse',
    'cycle_subtitle', 'cycle_subtitle_reverse', 'toggle_mute', 'set_volume',
    'select_audio_device', 'frame_step', 'frame_back_step',
    'toggle_fullscreen', 'toggle_maximized', 'minimize', 'toggle_ontop', 'toggle_loop',
    'screenshot', 'show_stats', 'download', 'show_message', 'close', 'playlist_shuffle',
    'playlist_first', 'playlist_last',
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
---@param mode 'relative'|'absolute'?
function HostActions:seek(seconds, mode)
    if mode == nil then
        mode = 'relative'
    elseif mode ~= 'relative' and mode ~= 'absolute' then
        raise(std.ValueError('HostActions.seek mode must be relative or absolute'))
    end
    return self:call('seek', require_finite('seek', seconds), mode)
end

---@param seconds number
---@param mode 'keyframe'|'exact'?
function HostActions:seek_to(seconds, mode)
    if mode == nil then
        mode = 'exact'
    elseif mode ~= 'keyframe' and mode ~= 'exact' then
        raise(std.ValueError('HostActions.seek_to mode must be keyframe or exact'))
    end
    return self:call('seek_to', require_finite('seek_to', seconds), mode)
end

---@param paused boolean
function HostActions:set_pause(paused)
    if type(paused) ~= 'boolean' then
        raise(std.TypeError('HostActions.set_pause expects a boolean'))
    end
    return self:call('set_pause', paused)
end

---@param seconds number
---@param x number
---@param y number
function HostActions:thumbfast_request(seconds, x, y)
    return self:call(
        'thumbfast_request',
        require_finite('thumbfast_request seconds', seconds),
        require_finite('thumbfast_request x', x),
        require_finite('thumbfast_request y', y))
end

function HostActions:thumbfast_clear()
    return self:call('thumbfast_clear')
end

---@param url string
function HostActions:open_url(url)
    if type(url) ~= 'string' or url == '' then
        raise(std.TypeError('HostActions.open_url expects a non-empty URL'))
    end
    if not url:match('^https?://') then
        raise(std.ValueError('HostActions.open_url only accepts http or https URLs'))
    end
    return self:call('open_url', url)
end

function HostActions:playlist_prev()
    return self:call('playlist_prev')
end

function HostActions:playlist_next()
    return self:call('playlist_next')
end

function HostActions:select_playlist()
    return self:call('select_playlist')
end

function HostActions:chapter_prev()
    return self:call('chapter_prev')
end

function HostActions:chapter_next()
    return self:call('chapter_next')
end

---@param index number
function HostActions:set_chapter(index)
    index = require_finite('set_chapter', index)
    if index < 0 or index ~= math.floor(index) then
        raise(std.ValueError('HostActions.set_chapter expects a non-negative integer'))
    end
    return self:call('set_chapter', index)
end

function HostActions:select_chapter()
    return self:call('select_chapter')
end

---@param kind 'audio'|'sub'
---@param id number|string
function HostActions:set_track(kind, id)
    if kind ~= 'audio' and kind ~= 'sub' then
        raise(std.ValueError('HostActions.set_track kind must be audio or sub'))
    end
    if type(id) ~= 'number' and type(id) ~= 'string' then
        raise(std.TypeError('HostActions.set_track id must be a number or string'))
    end
    if type(id) == 'number' then
        id = require_finite('set_track', id)
    end
    return self:call('set_track', kind, id)
end

function HostActions:clear_audio_filter()
    return self:call('clear_audio_filter')
end

function HostActions:select_audio_track()
    return self:call('select_audio_track')
end

function HostActions:load_audio_track()
    return self:call('load_audio_track')
end

function HostActions:clear_secondary_subtitle()
    return self:call('clear_secondary_subtitle')
end

function HostActions:select_subtitle()
    return self:call('select_subtitle')
end

function HostActions:cycle_audio()
    return self:call('cycle_audio')
end

function HostActions:cycle_audio_reverse()
    return self:call('cycle_audio_reverse')
end

function HostActions:cycle_subtitle()
    return self:call('cycle_subtitle')
end

function HostActions:cycle_subtitle_reverse()
    return self:call('cycle_subtitle_reverse')
end

function HostActions:toggle_mute()
    return self:call('toggle_mute')
end

---@param volume number
function HostActions:set_volume(volume)
    return self:call('set_volume', require_finite('set_volume', volume))
end

function HostActions:select_audio_device()
    return self:call('select_audio_device')
end

function HostActions:frame_step()
    return self:call('frame_step')
end

function HostActions:frame_back_step()
    return self:call('frame_back_step')
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

function HostActions:toggle_loop()
    return self:call('toggle_loop')
end

---@param flag string?
function HostActions:screenshot(flag)
    if flag ~= nil and type(flag) ~= 'string' then
        raise(std.TypeError('HostActions.screenshot flag must be a string'))
    end
    return self:call('screenshot', flag)
end

function HostActions:show_stats()
    return self:call('show_stats')
end

---@param url string
function HostActions:download(url)
    if type(url) ~= 'string' or url == '' then
        raise(std.TypeError('HostActions.download expects a non-empty URL'))
    end
    if not url:match('^https?://') then
        raise(std.ValueError('HostActions.download only accepts http or https URLs'))
    end
    return self:call('download', url)
end

---@param message string
---@param duration number?
function HostActions:show_message(message, duration)
    if type(message) ~= 'string' then
        raise(std.TypeError('HostActions.show_message message must be a string'))
    end
    if #message > 4000 then
        message = message:sub(1, 3997) .. '...'
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

function HostActions:playlist_shuffle()
    return self:call('playlist_shuffle')
end

function HostActions:playlist_first()
    return self:call('playlist_first')
end

function HostActions:playlist_last()
    return self:call('playlist_last')
end

---@class _HostActionsScopeOptions
---@field actions HostActions
---@field child Widget?
---@field key any?

---@class HostActionsScope : InheritedWidget
---@field actions HostActions
---@field child Widget?
---@overload fun(options: _HostActionsScopeOptions): self
local HostActionsScope = std.class.new('HostActionsScope', InheritedWidget)
local HostActionsScopeClass = HostActionsScope --[[@as std.class]]

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
