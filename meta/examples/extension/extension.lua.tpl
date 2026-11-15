-- Example Define payload source; host transport sends this code during initialization.
---@namespace example
---@using example
---@using elxosc

-- Capture only this payload's runtime environment; metadata declares no globals.
---@type elxosc.meta.Builtins
local builtins = {
    -- The analyzer cannot infer functions supplied by Define's sandbox.
    ---@diagnostic disable-next-line: undefined-global
    import_as = import_as,
    ---@diagnostic disable-next-line: undefined-global
    import = import,
    require = require,
    ---@diagnostic disable-next-line: undefined-global
    mod = mod,
    ---@diagnostic disable-next-line: undefined-global
    bind = bind,
    print = print,
    ---@diagnostic disable-next-line: undefined-global
    new_widget = new_widget,
    ---@diagnostic disable-next-line: undefined-global
    new_state = new_state,
}

local widgets = builtins.require('widgets')
local material = builtins.require('material')
local player = builtins.import_as('player')
local host = builtins.import_as('mp')

---@class Counter : StatefulWidget
---@field initial number
---@overload fun(initial: number): self
local Counter = builtins.new_widget('example.Counter')

function Counter:__init(initial)
    widgets.StatefulWidget.__init(self)
    self.initial = initial
end

---@class CounterState : State
---@field value number
---@overload fun(): self
local CounterState = builtins.new_state('example.CounterState')

function CounterState:__init()
    widgets.State.__init(self)
    self.value = 0
end

function CounterState:init_state()
    self.value = (self.widget --[[@as Counter]]).initial
end

function CounterState:build()
    return material.TextButton({
        child = widgets.Text('value=' .. self.value),
        on_click = function()
            self:set_state(function()
                self.value = self.value + 1
            end)
        end,
    })
end

function Counter:create_state()
    return CounterState()
end

---@class Controls
local controls = { Counter = Counter, Slider = material.Slider }
---@class Labels
local labels = { title = 'Counter', 'first', 'second' }
builtins.mod('example.controls', controls)
builtins.mod('example.labels', labels)

local local_controls = builtins.import_as('example.controls')
local local_labels = builtins.import_as('example.labels')
local slider = local_controls.Slider({ value = 0.5 })
local first_label = local_labels[1] or ''
local counter = local_controls.Counter(#first_label)
host.set_prop('user-data/example-type-hints', player.get_snapshot().time_pos)
builtins.bind('app.extension', widgets.Column({ children = { counter, slider } }))
