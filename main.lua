-- elxosc entry point (loaded by mpv as scripts/elxosc/main.lua).
--
-- Brings up the mpv host around a Widget tree and opens the define window:
--
--   1. build the scaffold — the tree that names the slots other scripts may
--      fill (`Widget.id` + `bind`, dev/design/WIDGETS.md);
--   2. start one `OverlayHost` pipeline with the player-owned main layer;
--   3. accept `define_start` / `define` / `define_end` for `define_window`
--      seconds, then seal and re-mount with the collected binds applied.
--
-- `bind`, Pages contributions and overlay declarations are applied after the Define
-- window closes, before the fresh roots are mounted. Runtime updates use State,
-- Provider or explicit host setters rather than re-running Define source.

local mp = require 'mp'

require 'elxlib_load' -- sets up elxlibs.*

local mpv_define = require 'host.mpv_define'
local overlay_host = require 'host.overlay_host'
local mpv_player_context = require 'host.mpv_player_context'
local player_context = require 'widget.player_context'
local demo_mod = require 'demo'
local player = require 'player'
local layout_widgets = require 'widget.widgets.layout'
local basic_widgets = require 'widget.widgets.basic'
local color = require 'foundation.color'
local geometry = require 'foundation.geometry'
local text_style = require 'text.text_style'

local MpDefine = mpv_define.MpDefine
local OverlayHost = overlay_host.OverlayHost
local MpPlayerContext = mpv_player_context.MpPlayerContext
local PlayerStore = player_context.PlayerStore
local Demo = demo_mod.Demo
local PlayerScaffold = player.PlayerScaffold
local PlayerShell = player.PlayerShell
local ShellVisibilityController = player.ShellVisibilityController
local Container = layout_widgets.Container
local Row = layout_widgets.Row
local Text = basic_widgets.Text
local OutlinedButton = basic_widgets.OutlinedButton
local TextButton = basic_widgets.TextButton
local Color = color.Color
local EdgeInsets = geometry.EdgeInsets
local TextStyle = text_style.TextStyle

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

local player_store = PlayerStore({ controls_visibility = 'auto' })
local player_updates = MpPlayerContext(player_store)
player_updates:observe('user-data/elxosc-controls-visibility', function(value, current)
    if value == 'auto' or value == 'always' or value == 'never' then
        return current:copy({ controls_visibility = value })
    end
    return nil
end)
player_updates:observe('user-data/elxosc-demo-count', function(value, current)
    return current:copy({ demo_count = tonumber(value) or 0 })
end)
player_updates:observe('user-data/elxosc-demo-event', function(value, current)
    return current:copy({ demo_event = value or 'ready' })
end)
local define = MpDefine({ player_store = player_store })
define:listen()

local shell_controller = ShellVisibilityController()
local function shell_controls()
    return {
        title_bar = Container({
            height = 36,
            color = Color.rgba(0x18202AE0),
            padding = EdgeInsets.symmetric(12, 6),
            child = Text('elxosc player', {
                style = TextStyle({ font_size = 16, bold = true }),
            }),
        }),
        timeline = Container({
            height = 5,
            color = Color.rgba(0x6AA8D8E0),
        }),
        bottom = Container({
            height = 48,
            color = Color.rgba(0x18202AE0),
            child = Row({
                spacing = 8,
                main_alignment = 'center',
                cross_alignment = 'center',
                children = {
                    OutlinedButton({
                        label = 'Play',
                        on_click = function() mp.commandv('cycle', 'pause') end,
                    }),
                    TextButton({
                        label = 'Reset demo',
                        on_click = function()
                            player_store:replace(player_store:get():copy({
                                demo_count = 0,
                                demo_event = 'reset',
                            }))
                        end,
                    }),
                },
            }),
        }),
        left = TextButton({
            label = 'Prev',
            on_click = function() mp.commandv('playlist-prev') end,
        }),
        right = TextButton({
            label = 'Next',
            on_click = function() mp.commandv('playlist-next') end,
        }),
    }
end

local function shell_root(scaffold)
    local controls = shell_controls()
    return PlayerShell({
        scaffold = scaffold,
        controller = shell_controller,
        title_bar = controls.title_bar,
        timeline = controls.timeline,
        bottom = controls.bottom,
        left = controls.left,
        right = controls.right,
    })
end

local host = OverlayHost({
    player_store = player_store,
    player_context = player_updates,
    on_pointer_move = function() shell_controller:pointer_move() end,
    on_pointer_leave = function() shell_controller:pointer_leave() end,
})
host:create('main', shell_root(PlayerScaffold({ middle_child = Demo() })), {
    z_policy = 'main',
    input_policy = 'interactive',
    player_store = player_store,
})

--- Re-apply the collected binds to a fresh scaffold and swap it in.
local shutting_down = false
local function remount()
    if shutting_down then
        return
    end
    host:update('main', shell_root(define:build_root(Demo())), {
        z_policy = 'main',
        input_policy = 'interactive',
        player_store = player_store,
    })
    define:mount_overlays(host)
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
end
mp.register_event('shutdown', shutdown_callback)
