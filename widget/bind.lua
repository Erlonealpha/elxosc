-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- `bind`: attach a widget to a named node while the tree is being assembled.
--
-- The point is the define phase: the host names the nodes a script may fill
-- (`Widget.id`), the script calls `bind(id, widget)`, and the registry writes
-- the widget into that node's child slot **before the tree is mounted**.
-- There is deliberately no runtime mutation of the widget tree: after `apply`
-- the tree is fixed, and only `set_state` rebuilds drive change.
--
-- Today the operation is just "set the target's `child` / `children`". Richer
-- behaviours (more ops, changing part of the target's own settings) layer on
-- the same registry without changing the call shape.

local std = require 'elxlibs.std'
local widget_mod = require 'widget.widget'

local StatelessWidget = widget_mod.StatelessWidget
local raise = std.raise

local M = {}

--- How a bound widget is written into its target node.
---@alias BindOp
--- |>'replace'
--- | 'replace_if_empty'
--- | 'append'
--- | 'insert'

---@class BindOpts
---@field op BindOp? defaults to "replace" for a `child` target, "append" for `children`
---@field position integer? 1-based index, used by "insert"

---@class BindRegistry : std.object
---@overload fun(): BindRegistry
local BindRegistry = std.class.new('BindRegistry')

function BindRegistry:__init()
    self._binds = {}
end

---@param id string
---@param widget Widget
---@param opts BindOpts?
function BindRegistry:add(id, widget, opts)
    local entries = self._binds[id]
    if not entries then
        entries = {}
        self._binds[id] = entries
    end
    entries[#entries + 1] = { id = id, widget = widget, opts = opts or {} }
end

---@param id string
---@return table[]
function BindRegistry:get(id)
    return self._binds[id] or {}
end

---@param id string
---@return boolean
function BindRegistry:has(id)
    return self._binds[id] ~= nil
end

function BindRegistry:clear()
    self._binds = {}
end

--- Write every recorded binding into `root` and its declared descendants.
--- Call once, after the define phase and before mounting.
---@param root Widget
---@return Widget root
function BindRegistry:apply(root)
    self:_visit(root)
    return root
end

---@param widget Widget
---@param entry { id: string, widget: Widget, opts: BindOpts }
local function apply_binding(widget, entry)
    local target = widget:bind_target()
    if target == nil then
        raise(std.RuntimeError(string.format(
            "bind('%s'): %s cannot receive children", entry.id, tostring(widget))))
    end
    local opts = entry.opts
    if target == 'child' then
        local op = opts.op or 'replace'
        if op == 'replace' then
            widget.child = entry.widget
        elseif op == 'replace_if_empty' then
            if widget.child == nil then
                widget.child = entry.widget
            end
        else
            raise(std.ValueError(string.format(
                "bind('%s'): op '%s' is not valid for a single-child target", entry.id, op)))
        end
        return
    end
    local op = opts.op or 'append'
    local children = widget.children
    if children == nil then
        children = {}
        widget.children = children
    end
    if op == 'append' then
        children[#children + 1] = entry.widget
    elseif op == 'insert' then
        table.insert(children, opts.position or (#children + 1), entry.widget)
    else
        raise(std.ValueError(string.format(
            "bind('%s'): op '%s' is not valid for a multi-child target", entry.id, op)))
    end
end

---@param widget Widget
function BindRegistry:_visit(widget)
    local id = widget.id
    if id ~= nil then
        for _, entry in ipairs(self:get(id)) do
            apply_binding(widget, entry)
        end
    end
    for _, child in ipairs(widget:child_widgets()) do
        self:_visit(child)
    end
end

--- Sugar for the definition sandbox: `bind(registry, 'title_bar', widget)`.
---@param registry BindRegistry
---@param id string
---@param widget Widget
---@param opts BindOpts?
function M.bind(registry, id, widget, opts)
    registry:add(id, widget, opts)
end

--- An empty place a script can fill: a node carrying an `id` and no children
--- of its own. Unbound it contributes nothing to the render tree.
---@class Slot : StatelessWidget
---@field child Widget?
---@overload fun(id: string, options: { key: any? }?): Slot
local Slot = std.class.new('Slot', { StatelessWidget })

function Slot:__init(id, options)
    options = options or {}
    self.key = options.key
    self.id = id
    self.child = nil
end

function Slot:child_widgets()
    return self.child and { self.child } or {}
end

function Slot:bind_target()
    return 'child'
end

function Slot:build()
    return self.child
end

M.BindRegistry = BindRegistry
M.Slot = Slot

return M
