-- Example Define payload source; host transport sends this code during initialization.
---@namespace example
---@using example
---@using elxosc

local widgets = import_as('widgets')
local material = import_as('material')
local player = import_as('player')
local dsl = import_as('define.dsl')
local host = import_as('mp')

---@class Counter : StatefulWidget
---@field initial number
---@overload fun(initial: number): self
local Counter = dsl.new_widget('example.Counter')

function Counter:__init(initial)
    widgets.StatefulWidget.__init(self)
    self.initial = initial
end

---@class CounterState : State
---@field value number
---@overload fun(): self
local CounterState = dsl.new_state('example.CounterState')

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
mod('example.controls', controls)
mod('example.labels', labels)

local local_controls = import_as('example.controls')
local local_labels = import_as('example.labels')
local slider = local_controls.Slider({ value = 0.5 })
local first_label = local_labels[1] or ''
local counter = local_controls.Counter(#first_label)
host.set_prop('user-data/example-type-hints', player.get_snapshot().time_pos)
bind('app.extension', widgets.Column({ children = { counter, slider } }))
