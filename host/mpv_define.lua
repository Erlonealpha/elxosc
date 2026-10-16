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
local bind_mod = require 'widget.bind'
local player_context = require 'widget.player_context'
local pages_mod = require 'player.registry'
local overlay_host_mod = require 'host.overlay_host'

local DefineSession = define_mod.DefineSession
local ModuleRegistry = modules_mod.ModuleRegistry
local BindRegistry = bind_mod.BindRegistry
local PlayerStore = player_context.PlayerStore
local PagesRegistry = pages_mod.PagesRegistry
local OverlayDeclarationRegistry = overlay_host_mod.OverlayDeclarationRegistry

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
function M.install_mp_module(modules, observe)
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
            return {
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
        end,
        message_to = function(...)
            mp.commandv('script-message-to', ...)
        end
    })

    modules:add_loader('mp', function(env, scope_id)
        -- Messages this scope can receive: `script-message-to elxosc <scope> ...`
        env.on_message = function(cb)
            mp.register_script_message(scope_id, cb)
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
function M.install_player_module(modules, store)
    modules:add('player', {
        get_snapshot = function()
            return store:get()
        end,
        on_update = function(callback)
            return store:subscribe(callback)
        end,
    })
    modules:protect('player')
end

--== the session ===========================================================

---@class MpDefineOptions
---@field builtins table<string, any>? names on top of the DSL defaults
---@field binds BindRegistry? shared bind registry
---@field modules ModuleRegistry? shared module registry (gets the `mp` module)
---@field player_store PlayerStore? host-independent player snapshot store
---@field pages PagesRegistry? initialization-time Pages declaration registry
---@field overlay OverlayDeclarationRegistry? initialization-time overlay registry

--- A `DefineSession` wired to mpv: the protocol messages, the `mp` module and
--- the window policy.
---@class MpDefine : std.object
---@field session DefineSession
---@field binds BindRegistry
---@field on_sealed fun()? called when the last `define_end` arrives
---@field player_store PlayerStore
---@field pages PagesRegistry
---@field overlays OverlayDeclarationRegistry
---@field _listening boolean
---@field _allow_start boolean
---@overload fun(options: MpDefineOptions?): self
local MpDefine = std.class.new('MpDefine', {})

function MpDefine:__init(options)
    options = options or {}
    self.binds = options.binds or BindRegistry()
    self.player_store = options.player_store or PlayerStore()
    self.pages = options.pages or PagesRegistry()
    self.overlays = options.overlay or options.overlays or OverlayDeclarationRegistry()
    self.on_sealed = nil
    self._listening = false
    self._allow_start = true

    local builtins = {}
    for name, value in pairs(options.builtins or dsl.builtins()) do
        builtins[name] = value
    end
    builtins['print'] = function(...)
        mp.msg.info(...)
    end

    local modules = options.modules or ModuleRegistry()
    M.install_mp_module(modules)
    M.install_player_module(modules, self.player_store)

    self.session = DefineSession({
        builtins = builtins,
        modules = modules,
        binds = self.binds,
        pages = self.pages,
        overlay = self.overlays,
    })
    self.session.on_error = function(scope_id, err)
        mp.msg.error(string.format("elxosc: define('%s') failed: %s", scope_id, tostring(err)))
    end
end

--- Start accepting the protocol messages. Non-blocking: mpv's own event pump
--- (running after this script's main chunk returns) delivers them.
function MpDefine:listen()
    if self._listening then
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

--- Apply the collected binds to the scaffold widget and hand it back.
---@param root Widget
---@return Widget
function MpDefine:apply(root)
    return self.binds:apply(root)
end

--- Assemble the host-independent Pages tree after the Define session is sealed.
--- The fallback child belongs to the player and is never extension content.
---@param middle_child Widget
---@return Widget
function MpDefine:build_root(middle_child)
    local root = self.pages:assemble({ middle_child = middle_child })
    return self:apply(root)
end

--- Freeze extension overlay declarations and hand them to the host-owned layer
--- manager. The sandbox never receives the host or any presenter directly.
---@param host OverlayHost
---@return LayerRecord[]
function MpDefine:mount_overlays(host)
    return host:mount_declarations(self.overlays:freeze())
end

M.MpDefine = MpDefine

return M
