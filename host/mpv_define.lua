-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- The mpv side of the define protocol (dev/design/HOST.md).
--
-- The framework owns the protocol; this module owns the three things it
-- deliberately does not:
--   * the transport — `script-message-to elxosc define_start|define|define_end`;
--   * the `mp` module (data + loader) that scripts `import`;
--   * the define window policy — when it opens, when it stops accepting new
--     starters, and what happens to a script that never sends its `define_end`.

local mp = require 'mp'

local std = require 'elxlibs.std'
local dsl = require 'libs.dsl'
local define_mod = require 'libs.define'
local modules_mod = require 'libs.modules'
local slot_mod = require 'widget.slot'
local player_context = require 'widget.player_context'

local DefineSession = define_mod.DefineSession
local ModuleRegistry = modules_mod.ModuleRegistry
local CompositionAssembler = slot_mod.CompositionAssembler
local PlayerStore = player_context.PlayerStore
local raise = std.raise

local M = {}

--== the `mp` module =======================================================

--- Register the `mp` module: plain data for the request/response helpers, plus a
--- loader for the one that needs the importing scope.
---
--- This is why `mods` and `loaders` are separate tables: the framework never
--- learns what `mp` is, and `on_message` is scope-specific because the loader
--- receives the scope id.
---@param modules ModuleRegistry
---@param observe fun(name: string, cb: fun(name: string, value: any))? defaults to `mp.observe_property`
---@param register_disposer fun(dispose: fun())?
function M.install_mp_module(modules, observe, register_disposer)
    observe = observe or function(name, cb)
        mp.observe_property(name, 'native', cb)
    end

    modules:add('mp', {
        get_prop = function(name)
            return mp.get_property_native(name)
        end,
        set_prop = function(name, value)
            mp.set_property_native(name, value)
        end,
        get_time = function()
            return mp.get_time()
        end,
        command = function(...)
            return mp.commandv(...)
        end,
        log = function(...)
            mp.msg.info(...)
        end,
        --- `cb(name, value)`, the same shape `mp.observe_property` uses.
        on_prop = function(name, cb)
            if type(name) ~= 'string' or name == '' then
                error('mp.on_prop expects a non-empty property name', 2)
            end
            if type(cb) ~= 'function' then
                error('mp.on_prop expects a callback', 2)
            end
            observe(name, cb)
            local active = true
            local subscription = {
                is_active = function()
                    return active
                end,
                dispose = function()
                    if not active then
                        return false
                    end
                    active = false
                    if mp.unobserve_property then
                        mp.unobserve_property(cb)
                    end
                    return true
                end,
            }
            if register_disposer then
                register_disposer(subscription.dispose)
            end
            return subscription
        end,
        on_event = function(name, cb)
            if type(name) ~= 'string' or name == '' then
                error('mp.on_event expects a non-empty event name', 2)
            end
            if type(cb) ~= 'function' then
                error('mp.on_event expects a callback', 2)
            end
            if not mp.register_event then
                error('mp.on_event is unavailable on this host', 2)
            end
            mp.register_event(name, cb)
            local active = true
            local subscription = {
                is_active = function()
                    return active
                end,
                dispose = function()
                    if not active then
                        return false
                    end
                    active = false
                    if mp.unregister_event then
                        mp.unregister_event(cb)
                    end
                    return true
                end,
            }
            if register_disposer then
                register_disposer(subscription.dispose)
            end
            return subscription
        end,
        message_to = function(...)
            mp.commandv('script-message-to', ...)
        end
    })

    modules:add_loader('mp', function(env, scope_id)
        -- Messages this scope can receive: `script-message-to elxosc <scope> ...`
        env.on_message = function(cb)
            mp.register_script_message(scope_id, cb)
            local active = true
            local subscription = {
                is_active = function()
                    return active
                end,
                dispose = function()
                    if not active then
                        return false
                    end
                    active = false
                    if mp.unregister_script_message then
                        mp.unregister_script_message(scope_id)
                    end
                    return true
                end,
            }
            if register_disposer then
                register_disposer(subscription.dispose)
            end
            return subscription
        end
        env.emit = function(...)
            mp.commandv('script-message', scope_id, ...)
        end
    end)

    -- the facade belongs to the host; a script must not be able to replace it
    modules:protect('mp')
end

---@param modules ModuleRegistry
---@param store PlayerStore
---@param register_disposer fun(dispose: fun())?
function M.install_player_module(modules, store, register_disposer)
    modules:add('player', {
        get_snapshot = function()
            return store:get()
        end,
        on_update = function(callback)
            local subscription = store:subscribe(callback)
            if register_disposer then
                register_disposer(subscription.dispose)
            end
            return subscription
        end,
    })
    modules:protect('player')
end

--== the session ===========================================================

---@class MpDefineOptions
---@field builtins table<string, any>? names on top of the DSL defaults
---@field contributions ContributionRegistry? shared contribution registry
---@field modules ModuleRegistry? shared module registry (gets the `mp` module)
---@field player_store PlayerStore? host-independent player snapshot store

--- A `DefineSession` wired to mpv: the protocol messages, the `mp` module and
--- the window policy.
---@class MpDefine : std.object
---@field session DefineSession
---@field on_sealed fun()? called when the last `define_end` arrives
---@field player_store PlayerStore
---@field _listening boolean
---@field _allow_start boolean
---@field _disposers fun()[]
---@field _shutdown boolean
---@field _assembled boolean
---@field _payload_disposer_mark integer?
---@overload fun(options: MpDefineOptions?): self
local MpDefine = std.class.new('MpDefine', {})

function MpDefine:__init(options)
    options = options or {}
    self.player_store = options.player_store or PlayerStore()
    self.on_sealed = nil
    self._listening = false
    self._allow_start = true
    self._disposers = {}
    self._shutdown = false
    self._assembled = false
    self._payload_disposer_mark = nil

    local function register_disposer(dispose)
        self._disposers[#self._disposers + 1] = dispose
    end

    local builtins = {}
    for name, value in pairs(options.builtins or dsl.builtins()) do
        builtins[name] = value
    end
    builtins['print'] = function(...)
        mp.msg.info(...)
    end

    local modules = options.modules or ModuleRegistry()
    M.install_mp_module(modules, nil, register_disposer)
    M.install_player_module(modules, self.player_store, register_disposer)

    self.session = DefineSession({
        builtins = builtins,
        modules = modules,
        contributions = options.contributions,
    })
    self.session.on_payload_begin = function()
        self._payload_disposer_mark = #self._disposers
    end
    self.session.on_payload_commit = function()
        self._payload_disposer_mark = nil
    end
    self.session.on_payload_rollback = function()
        local mark = self._payload_disposer_mark or #self._disposers
        for index = #self._disposers, mark + 1, -1 do
            self._disposers[index]()
            self._disposers[index] = nil
        end
        self._payload_disposer_mark = nil
    end
    self.session.on_error = function(scope_id, err)
        mp.msg.error(string.format("elxosc: define('%s') failed: %s", scope_id, tostring(err)))
    end
end

--- Start accepting the protocol messages. Non-blocking: mpv's own event pump
--- (running after this script's main chunk returns) delivers them.
function MpDefine:listen()
    if self._shutdown or self._listening then
        return
    end
    self._listening = true

    mp.register_script_message('define_start', function()
        if not self._allow_start then
            mp.msg.warn('elxosc: define_start ignored, the define window is closed')
            return
        end
        self.session:define_start()
    end)

    mp.register_script_message('define', function(scope_id, code)
        if self.session.phase == 'idle' then
            mp.msg.warn('elxosc: define ignored, no define_start was received')
            return
        end
        self.session:define(scope_id, code)
    end)

    mp.register_script_message('define_end', function()
        self.session:define_end()
        if self.session.phase == 'sealed' and self.on_sealed ~= nil then
            self.on_sealed()
        end
    end)
end

function MpDefine:unlisten()
    if not self._listening then
        return
    end
    self._listening = false
    mp.unregister_script_message('define_start')
    mp.unregister_script_message('define')
    mp.unregister_script_message('define_end')
end

--- Stop accepting new starters and seal the session. A script that sent its
--- `define_start` but never its `define_end` must not leave the window open.
function MpDefine:close()
    self._allow_start = false
    self:unlisten()
    while self.session.phase == 'defining' do
        self.session:define_end()
    end
end

--- Release host observers and scope message registrations at shutdown.
---@return boolean
function MpDefine:shutdown()
    if self._shutdown then
        return false
    end
    self._shutdown = true
    self._allow_start = false
    self:unlisten()
    for index = #self._disposers, 1, -1 do
        self._disposers[index]()
    end
    self._disposers = {}
    return true
end

---@return boolean
function MpDefine:is_sealed()
    return self.session.phase == 'sealed'
end

--- Pump mpv events until every `define_start` has been matched by a
--- `define_end`, or the deadlines pass (dev/feat_example.lua's `wait_define`).
---
--- Blocking, so it only suits a host that wants the whole tree defined before
--- the UI appears. `main.lua` prefers `listen()` plus a timeout, which keeps
--- mpv's startup non-blocking.
---@param wait_start number? seconds during which `define_start` is accepted
---@param all_timeout number? total seconds the window may last
---@return boolean sealed
function MpDefine:wait(wait_start, all_timeout)
    wait_start = wait_start or 0.5
    all_timeout = all_timeout or 1
    self:listen()
    self._allow_start = true

    local start = mp.get_time()
    local deadline_start = start + wait_start
    local deadline = start + all_timeout
    while true do
        local now = mp.get_time()
        if now >= deadline then
            break
        end
        if now >= deadline_start then
            self._allow_start = false
        end
        local until_next = (self._allow_start and deadline_start or deadline) - now
        if until_next > 0 then
            mp.wait_event(until_next)
        end
        if self.session.phase == 'sealed' then
            break
        end
    end

    self:close()
    return self.session.phase == 'sealed'
end

--- Assemble the sealed Define contributions into a fresh Widget description.
---@param root Widget
---@return Widget
---@return table[] diagnostics
function MpDefine:assemble(root)
    if not self:is_sealed() then
        raise(std.RuntimeError('cannot assemble before define_end'))
    end
    if self._assembled then
        raise(std.RuntimeError('Define contributions have already been assembled'))
    end
    local assembler = CompositionAssembler(self.session:contribution_snapshot(), {
        on_warning = function(diagnostic)
            mp.msg.warn(string.format(
                "elxosc: slot '%s': %s",
                tostring(diagnostic.slot_id),
                tostring(diagnostic.message)))
        end,
    })
    local assembled, diagnostics = assembler:assemble(root)
    self._assembled = true
    return assembled, diagnostics
end

M.MpDefine = MpDefine

return M
