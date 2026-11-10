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
local player_exports = require 'widget.player.exports'
local exports_mod = require 'libs.exports'
local geometry = require 'foundation.geometry'
local color = require 'foundation.color'
local paint = require 'painting.paint'
local text_style = require 'text.text_style'
local transform = require 'foundation.transform'
local anchor = require 'foundation.anchor'
local text_paint = require 'painting.text_paint'

local DefineSession = define_mod.DefineSession
local ModuleRegistry = modules_mod.ModuleRegistry
local CompositionAssembler = slot_mod.CompositionAssembler
local PlayerStore = player_context.PlayerStore
local raise = std.raise

---@class elxosc.host.mpv_define
local M = {}

---@class MpFacadeSubscription
---@field is_active fun(): boolean
---@field dispose fun(): boolean

---@class MpFacadeExports
---@field get_prop fun(name: string): any
---@field set_prop fun(name: string, value: any)
---@field get_time fun(): number
---@field command fun(...: any): boolean?, string?
---@field log fun(...: any)
---@field on_prop fun(name: string, callback: fun(name: string, value: any)): MpFacadeSubscription
---@field on_event fun(name: string, callback: fun(event: table)): MpFacadeSubscription
---@field message_to fun(...: any)

---@class MpScopeExports
---@field on_message fun(callback: fun(...: any)): MpFacadeSubscription
---@field emit fun(...: any)

---@alias elxosc.host.mpv_define.mp MpFacadeExports & MpScopeExports

---@class PlayerRuntimeExports
---@field get_snapshot fun(): PlayerSnapshot
---@field on_update fun(callback: fun(snapshot: PlayerSnapshot, previous: PlayerSnapshot)): PlayerSubscription

---@alias elxosc.host.mpv_define.player elxosc.widget.player.components & PlayerRuntimeExports

--- Explicit default scope surface; adding a package does not expand builtins.
---@return DefineBuiltins
function M.builtins()
    local widgets = require 'widget'
    ---@class DefineBuiltins
    local out = {
        Widget = widgets.Widget,
        StatelessWidget = widgets.StatelessWidget,
        StatefulWidget = widgets.StatefulWidget,
        ProxyWidget = widgets.ProxyWidget,
        ParentDataWidget = widgets.ParentDataWidget,
        InheritedWidget = widgets.InheritedWidget,
        RenderObjectWidget = widgets.RenderObjectWidget,
        LeafRenderObjectWidget = widgets.LeafRenderObjectWidget,
        SingleChildRenderObjectWidget = widgets.SingleChildRenderObjectWidget,
        MultiChildRenderObjectWidget = widgets.MultiChildRenderObjectWidget,
        State = widgets.State,
        Key = widgets.Key,
        LocalKey = widgets.LocalKey,
        UniqueKey = widgets.UniqueKey,
        ValueKey = widgets.ValueKey,
        ObjectKey = widgets.ObjectKey,
        GlobalKey = widgets.GlobalKey,
        Provider = widgets.Provider,
        PlayerProvider = widgets.PlayerProvider,
        PlayerCapability = widgets.PlayerCapability,
        PlayerSnapshot = widgets.PlayerSnapshot,
        PlayerScope = widgets.PlayerScope,
        Theme = widgets.Theme,
        ThemeData = widgets.ThemeData,
        DefaultTextStyle = widgets.DefaultTextStyle,
        DisplaySnapshot = widgets.DisplaySnapshot,
        DisplayScope = widgets.DisplayScope,
        HostActions = widgets.HostActions,
        HostActionsScope = widgets.HostActionsScope,
        Opacity = widgets.Opacity,
        Offstage = widgets.Offstage,
        Visibility = widgets.Visibility,
        AutoHide = widgets.AutoHide,
        AutoHideController = widgets.AutoHideController,
        Overlay = widgets.Overlay,
        OverlayEntry = widgets.OverlayEntry,
        OverlayEntryWidget = widgets.OverlayEntryWidget,
        OverlayScope = widgets.OverlayScope,
        Theatre = widgets.Theatre,
        Navigator = widgets.Navigator,
        NavigatorScope = widgets.NavigatorScope,
        Page = widgets.Page,
        PopupPage = widgets.PopupPage,
        Route = widgets.Route,
        PopupRoute = widgets.PopupRoute,
        RouteResult = widgets.RouteResult,
        ModalBarrier = widgets.ModalBarrier,
        WidgetsApp = widgets.WidgetsApp,
        DefaultApp = widgets.DefaultApp,
        Main = widgets.Main,
        PlayerMain = widgets.PlayerMain,
        WindowLayer = widgets.WindowLayer,
        PlayerTheme = widgets.PlayerTheme,
        PlayerThemeData = widgets.PlayerThemeData,
        PlayerLayout = widgets.PlayerLayout,
        PlayerDescriptionLayer = widgets.PlayerDescriptionLayer,
        PlayerControlBar = widgets.PlayerControlBar,
        PlayerControlButton = widgets.PlayerControlButton,
        PlayerTimeDisplay = widgets.PlayerTimeDisplay,
        PlayerHoverText = widgets.PlayerHoverText,
        PlayerTooltip = widgets.PlayerTooltip,
        PlayerIcons = widgets.PlayerIcons,
        Timeline = widgets.Timeline,
        SlotSpec = widgets.SlotSpec,
        SlotWrap = widgets.SlotWrap,
        Text = widgets.Text,
        Icon = widgets.Icon,
        CustomPaint = widgets.CustomPaint,
        GestureDetector = widgets.GestureDetector,
        Button = widgets.Button,
        ButtonBase = widgets.ButtonBase,
        ButtonStyle = widgets.ButtonStyle,
        ElevatedButton = widgets.ElevatedButton,
        OutlinedButton = widgets.OutlinedButton,
        TextButton = widgets.TextButton,
        IconButton = widgets.IconButton,
        Tooltip = widgets.Tooltip,
        LinearProgressIndicator = widgets.LinearProgressIndicator,
        Slider = widgets.Slider,
        HoverText = widgets.HoverText,
        Padding = widgets.Padding,
        Align = widgets.Align,
        Center = widgets.Center,
        SizedBox = widgets.SizedBox,
        DecoratedBox = widgets.DecoratedBox,
        Flexible = widgets.Flexible,
        Expanded = widgets.Expanded,
        Spacer = widgets.Spacer,
        Flex = widgets.Flex,
        Row = widgets.Row,
        Column = widgets.Column,
        Stack = widgets.Stack,
        Positioned = widgets.Positioned,
        ConstrainedBox = widgets.ConstrainedBox,
        LimitedBox = widgets.LimitedBox,
        UnconstrainedBox = widgets.UnconstrainedBox,
        OverflowBox = widgets.OverflowBox,
        FittedBox = widgets.FittedBox,
        Container = widgets.Container,
        OffsetBox = widgets.OffsetBox,
        TransformBox = widgets.TransformBox,
        LayoutScaleBox = widgets.LayoutScaleBox,
        Offset = geometry.Offset,
        Point = geometry.Point,
        Size = geometry.Size,
        Rect = geometry.Rect,
        EdgeInsets = geometry.EdgeInsets,
        Color = color.Color,
        Paint = paint.Paint,
        TextStyle = text_style.TextStyle,
        Matrix2D = transform.Matrix2D,
        Anchor = anchor.Anchor,
        TextPaint = text_paint.TextPaint,
        new_widget = dsl.new_widget,
        new_state = dsl.new_state,
    }
    return out
end

--== the `mp` module =======================================================

--- Describe the `mp` module: plain data for the request/response helpers, plus a
--- loader for the one that needs the importing scope.
---
--- This is why `mods` and `loaders` are separate tables: the framework never
--- learns what `mp` is, and `on_message` is scope-specific because the loader
--- receives the scope id.
---@param observe fun(name: string, cb: fun(name: string, value: any))? defaults to `mp.observe_property`
---@param register_disposer fun(dispose: fun())?
---@return DefinePackage<MpFacadeExports>
local function mp_package(observe, register_disposer)
    observe = observe or function(name, cb)
        mp.observe_property(name, 'native', cb)
    end

    ---@type MpFacadeExports
    local exports = {
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
    }

    local function loader(env, scope_id)
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
    end

    return { name = 'mp', exports = exports, loader = loader }
end

---@param store PlayerStore
---@param register_disposer fun(dispose: fun())?
---@return DefinePackage<elxosc.host.mpv_define.player>
local function player_package(store, register_disposer)
    ---@type elxosc.host.mpv_define.player
    local exports = {}
    for name, value in pairs(player_exports.exports) do
        exports[name] = value
    end
    exports.get_snapshot = function()
        return store:get()
    end
    exports.on_update = function(callback)
        local subscription = store:subscribe(callback)
        if register_disposer then
            register_disposer(function()
                subscription:dispose()
            end)
        end
        return subscription
    end
    return { name = player_exports.name, exports = exports }
end

---@param modules ModuleRegistry
---@param observe fun(name: string, cb: fun(name: string, value: any))?
---@param register_disposer fun(dispose: fun())?
function M.install_mp_module(modules, observe, register_disposer)
    modules_mod.register_package(modules, mp_package(observe, register_disposer))
end

---@param modules ModuleRegistry
---@param store PlayerStore
---@param register_disposer fun(dispose: fun())?
function M.install_player_module(modules, store, register_disposer)
    modules_mod.register_package(modules, player_package(store, register_disposer))
end

--- Every extension package is registered here; runtime packages add owned APIs.
---@param modules ModuleRegistry
---@param store PlayerStore
---@param register_disposer fun(dispose: fun())?
function M.install_modules(modules, store, register_disposer)
    ---@type DefinePackage<table>[]
    local packages = exports_mod.collect()
    packages[#packages + 1] = mp_package(nil, register_disposer)
    for i, package in ipairs(packages) do
        if package.name == player_exports.name then
            packages[i] = player_package(store, register_disposer)
        end
    end
    for _, package in ipairs(packages) do
        modules_mod.register_package(modules, package)
    end
end

--== the session ===========================================================

---@class MpDefineOptions
---@field builtins table<string, any>? replaces the host-selected defaults
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
local MpDefine = std.class.new('MpDefine')

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
    for name, value in pairs(options.builtins or M.builtins()) do
        builtins[name] = value
    end
    builtins['print'] = mp.msg.info

    local modules = options.modules or ModuleRegistry()
    M.install_modules(modules, self.player_store, register_disposer)

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
    if self.session.phase == 'idle' then
        self.session.phase = 'sealed'
        return
    end
    while self.session.phase ~= 'sealed' do
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
