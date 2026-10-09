-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

---@diagnostic disable: undefined-field, inject-field, generic-constraint-mismatch

local std = require 'elxlibs.std'
local RenderFlex = require('render.flex').RenderFlex
local SizedBox = require('widget.widgets.sized_box').SizedBox
local widget = require 'widget.widget'

local Flexible = std.class.new('Flexible', { widget.ParentDataWidget })
function Flexible:__init(child, options)
    options = options or {}
    self.key, self.id, self.child = options.key, options.id, child
    self.flex, self.fit = options.flex or 1, options.fit or 'loose'
end
function Flexible:apply_parent_data(render_object)
    local parent_data = render_object.parent_data
    local changed = parent_data.flex ~= self.flex or parent_data.fit ~= self.fit
    parent_data.flex, parent_data.fit = self.flex, self.fit
    if changed and render_object.parent then render_object.parent:mark_needs_layout() end
end

local function Expanded(child, options)
    options = options or {}
    return Flexible(child, { key = options.key, id = options.id, flex = options.flex or 1, fit = 'tight' })
end
local function Spacer(options)
    options = options or {}
    return Expanded(SizedBox.shrink(), { key = options.key, id = options.id, flex = options.flex or 1 })
end

local Flex = std.class.new('Flex', { widget.MultiChildRenderObjectWidget })
function Flex:__init(direction, options)
    options = options or {}
    self.key, self.id = options.key, options.id
    self.direction, self.children = direction or 'row', options.children or {}
    self.main_alignment, self.main_axis_size = options.main_alignment or 'start', options.main_axis_size or 'max'
    self.cross_alignment, self.spacing = options.cross_alignment or 'center', options.spacing or 0
end
function Flex:create_render_object()
    return RenderFlex(self.direction, { main_alignment = self.main_alignment, main_axis_size = self.main_axis_size,
        cross_alignment = self.cross_alignment, spacing = self.spacing })
end
function Flex:update_render_object(render_object)
    render_object.direction, render_object.main_alignment = self.direction, self.main_alignment
    render_object.main_axis_size, render_object.cross_alignment = self.main_axis_size, self.cross_alignment
    render_object.spacing = self.spacing
    render_object:mark_needs_layout()
end
local function Row(options) return Flex('row', options) end
local function Column(options) return Flex('column', options) end

return { Flexible = Flexible, Expanded = Expanded, Spacer = Spacer, Flex = Flex, Row = Row, Column = Column }
