-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

local std = require 'elxlibs.std'
local constraints_mod = require 'layout.constraints'
local decorated_render_mod = require 'render.decorated_box'
local padding_mod = require 'widget.widgets.padding'
local align_mod = require 'widget.widgets.align'
local decorated_box_mod = require 'widget.widgets.decorated_box'
local constrained_box_mod = require 'widget.widgets.constraints'
local widget_mod = require 'widget.widget'

local Constraints = constraints_mod.Constraints
local Decoration = decorated_render_mod.Decoration
local Padding = padding_mod.Padding
local Align = align_mod.Align
local DecoratedBox = decorated_box_mod.DecoratedBox
local ConstrainedBox = constrained_box_mod.ConstrainedBox
local LimitedBox = constrained_box_mod.LimitedBox
local StatelessWidget = widget_mod.StatelessWidget

---@class _ContainerOptions
---@field child? Widget
---@field padding? EdgeInsets
---@field margin? EdgeInsets
---@field alignment? Offset
---@field width? number
---@field height? number
---@field constraints? Constraints
---@field decoration? Decoration
---@field color? Color
---@field radius? number
---@field border_width? number
---@field border_color? Color
---@field key? any
---@field id? string

--- A convenience composition of margin / sizing / decoration / alignment /
--- padding (Flutter's `Container`). It owns no render object of its own; the
--- whole thing is expressed with the widgets above.
---@class Container : StatelessWidget
---@field child? Widget
---@field padding? EdgeInsets
---@field margin? EdgeInsets
---@field alignment? Offset
---@field decoration? Decoration
---@field constraints? Constraints
---@overload fun(options?: _ContainerOptions): self
local Container = std.class.new('Container', { StatelessWidget })

---@param options? _ContainerOptions
function Container:__init(options)
    options = options or {}
    self.key = options.key
    self.id = options.id
    self.child = options.child
    self.padding = options.padding
    self.margin = options.margin
    self.alignment = options.alignment
    self.decoration = options.decoration
        or (options.color and Decoration({
            color = options.color,
            radius = options.radius or 0,
            border_width = options.border_width or 0,
            border_color = options.border_color,
        }) or nil)
    -- `width`/`height` are folded into `constraints`, exactly like Flutter's
    -- constructor (`constraints?.tighten(...) ?? BoxConstraints.tightFor(...)`).
    local width = options.width
    local height = options.height
    local constraints = options.constraints
    if width ~= nil or height ~= nil then
        constraints = constraints and constraints:tighten({ width = width, height = height })
            or Constraints.tight_for({ width = width, height = height })
    end
    self.constraints = constraints
end

function Container:build()
    -- With no child, expand to fill a bounded box (so decoration shows), but
    -- collapse when unbounded; with a child, alignment precedes padding.
    local current = self.child
    if current == nil and (self.constraints == nil or not self.constraints:is_tight()) then
        current = LimitedBox({
            max_width = 0,
            max_height = 0,
            child = ConstrainedBox({ constraints = Constraints.expand() }),
        })
    elseif self.alignment then
        current = Align(current, { alignment = self.alignment })
    end
    if self.padding then
        current = Padding(current, { padding = self.padding })
    end
    if self.decoration then
        current = DecoratedBox(current, { decoration = self.decoration })
    end
    if self.constraints then
        current = ConstrainedBox({ constraints = self.constraints, child = current })
    end
    if self.margin then
        current = Padding(current, { padding = self.margin })
    end
    return current
end

function Container:child_widgets()
    return self.child and { self.child } or {}
end

function Container:bind_target()
    return 'child'
end

return { Container = Container }
