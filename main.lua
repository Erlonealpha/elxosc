-- elxosc entry point (loaded by mpv as scripts/elxosc/main.lua).
--
-- Brings up the mpv host around a Widget tree and opens the define window:
--
--   1. build the default Widget description and its explicit SlotSpec tree;
--   2. start the app, which drives the `WidgetBinding` frame loop (§9.1);
--   3. accept `define_start` / `define` / `define_end` for `define_window`
--      seconds, then seal and assemble a fresh description once.
--
-- Define contributions are assembled before the Widget tree is mounted. Runtime
-- Binding only owns mount/update/dispose and never applies contributions.

local enable = true
if not enable then
    return
end

local mp = require 'mp'

require 'elxlib_load' -- sets up elxlibs.*

local mpv_app = require 'host.mpv_app'
local mpv_define = require 'host.mpv_define'
local mpv_player_context = require 'host.mpv_player_context'
local player_context = require 'widget.player_context'
local main_layout = require 'main_layout'
local demo_mod = require 'demo'

local MpDefine = mpv_define.MpDefine
local MpPlayerContext = mpv_player_context.MpPlayerContext
local PlayerStore = player_context.PlayerStore
local Demo = demo_mod.Demo

-- Seconds the define window stays open. Long enough for every script to have
-- sent its payload, short enough not to be noticed; `define_end` from all
-- starters closes it early.
local define_window = 0.5

--== debug =================================================================

-- `host/mpv_input.lua` calls these globals; they belong in a `libs/debug.lua`
-- module (dev/design/HOST.md), but the host layer is being built out first.
local debug_enabled = true

function debug_msg(arg0, ...)
    if debug_enabled then
        if type(arg0) == 'function' then
            mp.msg.info('DEBUG', arg0())
        else
            mp.msg.info('DEBUG', arg0, ...)
        end
    end
end

function debug_msgf(arg0, ...)
    if debug_enabled then
        mp.msg.info('DEBUG', string.format(arg0, ...))
    end
end

--== start =================================================================

local player_store = PlayerStore()
local player_updates = MpPlayerContext(player_store)
player_updates:observe('user-data/elxosc-demo-count', function(value, current)
    return current:copy({ demo_count = tonumber(value) or 0 })
end)
player_updates:observe('user-data/elxosc-demo-event', function(value, current)
    return current:copy({ demo_event = value or 'ready' })
end)
local define = MpDefine({ player_store = player_store })
define:listen()

local function build_app()
    return main_layout.build_app(Demo())
end

local app = mpv_app.start(build_app, {
    player_store = player_store,
    player_context = player_updates,
})

--- Assemble the sealed contributions into a fresh application description and
--- swap it into the existing runtime tree.
local shutting_down = false
local function remount()
    if shutting_down then
        return
    end
    app:set_root_widget(define:assemble(main_layout.build_app_description(Demo())))
end

-- Fast path: every starter sent its `define_end`.
define.on_sealed = remount

-- Backstop: seal anyway once the window is over, so a script that forgets its
-- `define_end` cannot keep the session open (dev/design/HOST.md).
local define_timer = mp.add_timeout(define_window, function()
    if shutting_down then
        return
    end
    if define:is_sealed() then
        return
    end
    define:close()
    remount()
    mp.msg.info('elxosc: define window closed')
end)

---@type fun(ev: table)
local shutdown_callback
shutdown_callback = function(_event)
    shutting_down = true
    if define_timer and define_timer.kill then
        define_timer:kill()
    end
    if mp.unregister_event then
        mp.unregister_event(shutdown_callback)
    end
    define:shutdown()
end
mp.register_event('shutdown', shutdown_callback)
