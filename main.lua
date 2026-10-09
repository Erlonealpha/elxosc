-- elxosc entry point (loaded by mpv as scripts/elxosc/main.lua).
--
-- Brings up the mpv host around a Widget tree and opens the define window:
--
--   1. build the scaffold — the tree that names the slots other scripts may
--      fill (`Widget.id` + `bind`, DESIGN_PATH.md §7.2);
--   2. start the app, which drives the `WidgetBinding` frame loop (§9.1);
--   3. accept `define_start` / `define` / `define_end` for `define_window`
--      seconds, then seal and re-mount with the collected binds applied.
--
-- `bind` writes into the widget tree *before* it is mounted (DESIGN.md §4.4), so
-- the re-mount builds a fresh scaffold rather than mutating the live one.

local mp = require 'mp'

require 'elxlib_load' -- sets up elxlibs.*

local std = require 'elxlibs.std'

local color = require 'foundation.color'
local geometry = require 'foundation.geometry'
local text_style = require 'text.text_style'
local mpv_app = require 'host.mpv_app'
local mpv_define = require 'host.mpv_define'
local layout_widgets = require 'widget.widgets.layout'
local basic_widgets = require 'widget.widgets.basic'
local bind_mod = require 'widget.bind'
local state_mod = require 'widget.state'
local widget_mod = require 'widget.widget'

local Color = color.Color
local Offset = geometry.Offset
local EdgeInsets = geometry.EdgeInsets
local TextStyle = text_style.TextStyle
local MpDefine = mpv_define.MpDefine
local Slot = bind_mod.Slot
local State = state_mod.State
local StatefulWidget = widget_mod.StatefulWidget
local Column = layout_widgets.Column
local Center = layout_widgets.Center
local SizedBox = layout_widgets.SizedBox
local Container = layout_widgets.Container
local Text = basic_widgets.Text

-- Seconds the define window stays open. Long enough for every script to have
-- sent its payload, short enough not to be noticed; `define_end` from all
-- starters closes it early.
local define_window = 0.5

-- The names other scripts may bind to, and the matching `Widget.id`s below.
local SLOT = {
    top_left = 'top_left',
    top_right = 'top_right',
    bottom_bar = 'bottom_bar',
}

--== debug =================================================================

-- `host/mpv_input.lua` calls these globals; they belong in a `libs/debug.lua`
-- module (DESIGN_PATH.md §12), but the host layer is being built out first.
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

--== the demo payload ======================================================

-- Replaces the old hand-built RenderObject smoke tree: a stateful widget that
-- counts the `elxosc-demo` script messages, so `set_state` -> rebuild -> ASS
-- output can be eyeballed in mpv.

---@class DemoState : State
---@field count integer
---@overload fun(): DemoState
local DemoState = std.class.new('DemoState', { State })

function DemoState:__init()
    std.super(DemoState, self, State).__init(self)
    self.count = 0
end

function DemoState:init_state()
    -- `set_root_widget` may mount a fresh element (rather than reusing this
    -- one), so registering is made idempotent instead of assuming it runs once.
    mp.unregister_script_message('elxosc-demo')
    mp.register_script_message('elxosc-demo', function()
        self:set_state(function()
            self.count = self.count + 1
        end)
    end)
end

function DemoState:dispose()
    mp.unregister_script_message('elxosc-demo')
end

---@param context BuildContext
function DemoState:build(context)
    return Container{
        alignment = Offset(0.5, 0.5),
        padding = EdgeInsets.all(20),
        margin = EdgeInsets.only{left = 10, top = 10},
        color = Color.rgba255(0x20, 0x20, 0x20, 0xC0),
        radius = 6,
        child = Container{
            alignment = Offset(0.5, 0.5),
            padding = EdgeInsets.all(5),
            child = Text(string.format('elxosc  %d', self.count), {
                style = TextStyle(20, { color = Color.rgba255(0xF0, 0xF0, 0xF0) }),
            })
        },
    }
end

---@class Demo : StatefulWidget
---@overload fun(): Demo
local Demo = std.class.new('Demo', { StatefulWidget })

function Demo:create_state()
    return DemoState()
end

--== scaffold ==============================================================

--- The tree the host owns. An unbound `Slot` contributes nothing to the render
--- tree, so an unfilled slot costs no draw calls.
---@return Widget
local function build_scaffold()
    return Column({
        main_alignment = 'start',
        cross_alignment = 'start',
        children = {
            Slot(SLOT.top_left),
            Slot(SLOT.top_right),
            SizedBox({ height = 8 }),
            Demo(),
            SizedBox({ height = 8 }),
            Slot(SLOT.bottom_bar),
        },
    })
end

--== start =================================================================

local define = MpDefine()
define:listen()

local app = mpv_app.start(build_scaffold)

--- Re-apply the collected binds to a fresh scaffold and swap it in.
local function remount()
    app:set_root_widget(define:apply(build_scaffold()))
end

-- Fast path: every starter sent its `define_end`.
define.on_sealed = remount

-- Backstop: seal anyway once the window is over, so a script that forgets its
-- `define_end` cannot keep the session open (DESIGN.md §4.7.6).
mp.add_timeout(define_window, function()
    if define:is_sealed() then
        return
    end
    define:close()
    remount()
    mp.msg.info('elxosc: define window closed')
end)
