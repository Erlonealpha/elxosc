-- Mounted probes shared by runtime behavior tests.
---@diagnostic disable: undefined-field, inject-field, need-check-nil, generic-constraint-mismatch
local std = require 'elxlibs.std'
local widget_mod = require 'widget.widget'
local state_mod = require 'widget.state'
local layout_mod = require 'widget.widgets.layout'
local binding_mod = require 'widget.widgets_binding'
local constraints_mod = require 'layout.constraints'

local M = {}
local ProbeState = std.class.new('test.runtime.ProbeState', { state_mod.State })
function ProbeState:init_state()
    self.value = 10
    self.builds = 0
    self.disposals = 0
    if self.widget.on_init then
        self.widget.on_init(self)
    end
end
function ProbeState:build()
    self.builds = self.builds + 1
    if self.widget.on_build then
        return self.widget.on_build(self)
    end
    return layout_mod.SizedBox({ width = self.value, height = 10 })
end
function ProbeState:dispose()
    self.disposals = self.disposals + 1
    if self.widget.on_dispose then
        self.widget.on_dispose(self)
    end
end

local Probe = std.class.new('test.runtime.Probe', { widget_mod.StatefulWidget })
function Probe:__init(options)
    options = options or {}
    self.key = options.key
    self.on_init = options.on_init
    self.on_build = options.on_build
    self.on_dispose = options.on_dispose
end
function Probe:create_state()
    return ProbeState()
end

---@return WidgetTree
function M.mount(widget, scheduler)
    local tree = binding_mod.WidgetsBinding.ensure_initialized():attach(widget, nil, scheduler)
    tree.render_owner:set_viewport(constraints_mod.Constraints.loose(100, 100))
    tree.render_owner:flush_layout()
    return tree
end

function M.clock()
    local clock = { requests = 0 }
    function clock:set_handler(handler)
        self.handler = handler
    end
    function clock:request_frame()
        self.requests = self.requests + 1
    end
    function clock:pump(time)
        if self.handler then
            self.handler(time)
        end
    end
    return clock
end

M.Probe = Probe
return M
