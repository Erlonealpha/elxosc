-- elxosc entry point (loaded by mpv as scripts/elxosc/main.lua).
--
-- Brings up the mpv host around a Widget tree and opens the define window:
--
--   1. build the scaffold — the tree that names the slots other scripts may
--      fill (`Widget.id` + `bind`, dev/design/DESIGN_PATH.md §7.2);
--   2. start the app, which drives the `WidgetBinding` frame loop (§9.1);
--   3. accept `define_start` / `define` / `define_end` for `define_window`
--      seconds, then seal and re-mount with the collected binds applied.
--
-- `bind` writes into the widget tree *before* it is mounted (dev/design/DESIGN.md §4.4), so
-- the re-mount builds a fresh scaffold rather than mutating the live one.
---@diagnostic disable: undefined-field, call-non-callable, need-check-nil

local mp = require 'mp'

require 'elxlib_load' -- sets up elxlibs.*

local mpv_app = require 'host.mpv_app'
local mpv_define = require 'host.mpv_define'
local main_layout = require 'main_layout'

local MpDefine = mpv_define.MpDefine

-- Seconds the define window stays open. Long enough for every script to have
-- sent its payload, short enough not to be noticed; `define_end` from all
-- starters closes it early.
local define_window = 0.5

--== debug =================================================================

-- `host/mpv_input.lua` calls these globals; they belong in a `libs/debug.lua`
-- module (dev/design/DESIGN_PATH.md §12), but the host layer is being built out first.
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

local define = MpDefine()
define:listen()

local app = mpv_app.start(main_layout.build_scaffold)

--- Re-apply the collected binds to a fresh scaffold and swap it in.
local function remount()
    app:set_root_widget(define:apply(main_layout.build_scaffold()))
end

-- Fast path: every starter sent its `define_end`.
define.on_sealed = remount

-- Backstop: seal anyway once the window is over, so a script that forgets its
-- `define_end` cannot keep the session open (dev/design/DESIGN.md §4.7.6).
mp.add_timeout(define_window, function()
    if define:is_sealed() then
        return
    end
    define:close()
    remount()
    mp.msg.info('elxosc: define window closed')
end)
