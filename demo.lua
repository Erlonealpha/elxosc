-- elxosc demo widget used by the entry point and real-host smoke tests.

local mp = require 'mp'

local std = require 'elxlibs.std'

local color = require 'foundation.color'
local geometry = require 'foundation.geometry'
local text_style = require 'text.text_style'
local basic_widgets = require 'widget.widgets.basic'
local layout_widgets = require 'widget.widgets.layout'
local icon_mod = require 'widget.widgets.icon'
local state_mod = require 'widget.state'
local widget_mod = require 'widget.widget'

local Color = color.Color
local Offset = geometry.Offset
local EdgeInsets = geometry.EdgeInsets
local TextStyle = text_style.TextStyle
local State = state_mod.State
local StatefulWidget = widget_mod.StatefulWidget
local Column = layout_widgets.Column
local Row = layout_widgets.Row
local Container = layout_widgets.Container
local ElevatedButton = basic_widgets.ElevatedButton
local OutlinedButton = basic_widgets.OutlinedButton
local TextButton = basic_widgets.TextButton
local IconButton = basic_widgets.IconButton
local Icon = icon_mod.Icon
local Text = basic_widgets.Text

local M = {}

-- Replaces the old hand-built RenderObject smoke tree: a stateful widget that
-- counts the `elxosc-demo` script messages, so `set_state` -> rebuild -> ASS
-- output can be eyeballed in mpv.

---@class DemoState : State
---@field count integer
---@field selected string
---@overload fun(): DemoState
local DemoState = std.class.new('DemoState', { State })

function DemoState:__init()
    std.super(DemoState, self, State).__init(self)
    self.count = 0
    self.selected = 'ready'
end

function DemoState:init_state()
    -- `set_root_widget` may mount a fresh element (rather than reusing this
    -- one), so registering is made idempotent instead of assuming it runs once.
    mp.unregister_script_message('elxosc-demo')
    mp.register_script_message('elxosc-demo', function()
        self:set_state(function()
            self.count = self.count + 1
            self.selected = 'message'
            mp.set_property('user-data/elxosc-demo-count', tostring(self.count))
            mp.set_property('user-data/elxosc-demo-event', self.selected)
        end)
    end)
    mp.set_property('user-data/elxosc-demo-count', tostring(self.count))
    mp.set_property('user-data/elxosc-demo-event', self.selected)
end

function DemoState:dispose()
    mp.unregister_script_message('elxosc-demo')
end

function DemoState:_set_event(name)
    self:set_state(function()
        self.selected = name
        mp.set_property('user-data/elxosc-demo-event', name)
    end)
end

---@param context BuildContext
function DemoState:build(context)
    local content = Container{
        padding = EdgeInsets.all(20),
        color = Color.rgba(0x202020C0),
        radius = 6,
        child = Container{
            padding = EdgeInsets.all(5),
            child = Text(string.format('elxosc  %d', self.count), {
                style = TextStyle({ font_size = 20, color = Color.rgba255(0xF0, 0xF0, 0xF0) }),
            })
        },
    }
    return Container{
        alignment = Offset(0.5, 0.5),
        color = Color.rgba(0x63636372),
        child = Column({
            main_alignment = 'center',
            spacing = 6,
            children = {
                content,
                Container{
                    padding = EdgeInsets.all(5),
                    color = Color.rgba(0x2020206C),
                    child = Text('event: ' .. self.selected, {
                        style = TextStyle({ font_size = 14, color = Color.rgba255(180, 190, 205) }),
                    })
                },
                Row({
                    spacing = 6,
                    main_alignment = 'center',
                    children = {
                        IconButton{
                            icon = Icon('add', {
                                size = 24
                            }),
                            on_click = function()
                                self:set_state(function()
                                    self.count = self.count + 1
                                    self.selected = 'increment'
                                    mp.set_property('user-data/elxosc-demo-count', tostring(self.count))
                                    mp.set_property('user-data/elxosc-demo-event', self.selected)
                                end)
                            end,
                        },
                        OutlinedButton{
                            label = 'Reset',
                            on_click = function()
                                self:set_state(function()
                                    self.count = 0
                                    self.selected = 'reset'
                                    mp.set_property('user-data/elxosc-demo-count', '0')
                                    mp.set_property('user-data/elxosc-demo-event', self.selected)
                                end)
                            end,
                        },
                        TextButton{
                            label = 'Ping',
                            on_click = function() self:_set_event('ping') end,
                        },
                        IconButton{
                            icon = Text('!'),
                            on_click = function() self:_set_event('icon') end,
                        },
                    },
                }),
            },
        }),
    }
end

---@class Demo : StatefulWidget
---@overload fun(): Demo
local Demo = std.class.new('Demo', { StatefulWidget })

function Demo:create_state()
    return DemoState()
end

M.DemoState = DemoState
M.Demo = Demo

return M
