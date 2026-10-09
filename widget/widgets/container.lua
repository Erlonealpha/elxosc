-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

---@diagnostic disable: undefined-field, inject-field, generic-constraint-mismatch

local std = require 'elxlibs.std'
local geometry = require 'foundation.geometry'
local Constraints = require('layout.constraints').Constraints
local Decoration = require('render.decorated_box').Decoration
local Padding = require('widget.widgets.padding').Padding
local Align = require('widget.widgets.align').Align
local DecoratedBox = require('widget.widgets.decorated_box').DecoratedBox
local ConstrainedBox, LimitedBox = require('widget.widgets.constraints').ConstrainedBox, require('widget.widgets.constraints').LimitedBox
local StatelessWidget = require('widget.widget').StatelessWidget

local Container = std.class.new('Container', { StatelessWidget })
function Container:__init(options)
    options = options or {}
    self.key, self.id, self.child = options.key, options.id, options.child
    self.padding, self.margin, self.alignment = options.padding, options.margin, options.alignment
    self.decoration = options.decoration or (options.color and Decoration({ color = options.color,
        radius = options.radius or 0, border_width = options.border_width or 0, border_color = options.border_color }) or nil)
    local width, height, constraints = options.width, options.height, options.constraints
    if width ~= nil or height ~= nil then
        constraints = constraints and constraints:tighten({ width = width, height = height })
            or Constraints.tight_for({ width = width, height = height })
    end
    self.constraints = constraints
end
function Container:build()
    local current = self.child
    if current == nil and (self.constraints == nil or not self.constraints:is_tight()) then
        current = LimitedBox({ max_width = 0, max_height = 0, child = ConstrainedBox({ constraints = Constraints.expand() }) })
    elseif self.alignment then
        current = Align(current, { alignment = self.alignment })
    end
    if self.padding then current = Padding(current, { padding = self.padding }) end
    if self.decoration then current = DecoratedBox(current, { decoration = self.decoration }) end
    if self.constraints then current = ConstrainedBox({ constraints = self.constraints, child = current }) end
    if self.margin then current = Padding(current, { padding = self.margin }) end
    return current
end
function Container:child_widgets() return self.child and { self.child } or {} end
function Container:bind_target() return 'child' end

return { Container = Container }
