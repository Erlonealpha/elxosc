-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- A single-owner logical Overlay runtime.
--
-- OverlayEntry descriptors are mounted exactly once in the Overlay tree.  The
-- builder is invoked by a mounted Entry element, so returned State/Element
-- lifecycles are real framework lifecycles rather than a side table.  An
-- occluded or hidden entry may remain mounted behind RenderOffstage when
-- maintain_state is true; otherwise it is removed from the child list and
-- unmounted on the next build flush.

local std = require 'elxlibs.std'
local widget_mod = require 'widget.widget'
local state_mod = require 'widget.state'
local layout_widgets = require 'widget.widgets.layout'
local offstage_mod = require 'widget.visibility'

local StatefulWidget = widget_mod.StatefulWidget
local InheritedWidget = widget_mod.InheritedWidget
local StatelessWidget = widget_mod.StatelessWidget
local State = state_mod.State
local Stack = layout_widgets.Stack
local Offstage = offstage_mod.Offstage

local raise = std.raise

local M = {}

local function copy_array(values)
    local out = {}
    for index, value in ipairs(values or {}) do
        out[index] = value
    end
    return out
end

--== entries ================================================================

---@class _OverlayEntryOptions
---@field builder fun(context: BuildContext): Widget?
---@field opaque boolean?
---@field maintain_state boolean?
---@field visible boolean?
---@field key any?
---@field on_dispose fun(entry: OverlayEntry)? internal lifecycle hook

---@class OverlayEntry : std.object
---@field builder fun(context: BuildContext): Widget?
---@field opaque boolean
---@field maintain_state boolean
---@field visible boolean
---@field key any
---@field private _overlay OverlayState?
---@field private _mounted boolean
---@field private _disposed boolean
---@field private _finalized boolean
---@field private _on_dispose fun(entry: OverlayEntry)?
---@overload fun(options: _OverlayEntryOptions): self
local OverlayEntry = std.class.new('OverlayEntry', {})

function OverlayEntry:__init(options)
    if type(options) ~= 'table' then
        raise(std.TypeError('OverlayEntry expects an options table'))
    end
    if type(options.builder) ~= 'function' then
        raise(std.TypeError('OverlayEntry.builder must be a function'))
    end
    self.builder = options.builder
    self.opaque = options.opaque == true
    self.maintain_state = options.maintain_state ~= false
    self.visible = options.visible ~= false
    self.key = options.key or self
    self._on_dispose = options.on_dispose
    if self._on_dispose ~= nil and type(self._on_dispose) ~= 'function' then
        raise(std.TypeError('OverlayEntry.on_dispose must be a function'))
    end
    self._overlay = nil
    self._mounted = false
    self._disposed = false
    self._finalized = false
end

---@return boolean
function OverlayEntry:is_mounted()
    return self._mounted
end

---@return boolean
function OverlayEntry:is_attached()
    return self._overlay ~= nil
end

---@param state OverlayState
---@return boolean
function OverlayEntry:is_attached_to(state)
    return self._overlay == state
end

function OverlayEntry:_mark_removed()
    self._disposed = true
end

function OverlayEntry:_finalize()
    if self._finalized then
        return false
    end
    self._finalized = true
    local callback = self._on_dispose
    self._on_dispose = nil
    if callback then
        callback(self)
    end
    return true
end

---@return boolean
function OverlayEntry:is_removed()
    return self._overlay == nil and self._disposed
end

---@return boolean
function OverlayEntry:remove()
    if self._disposed then
        return false
    end
    if self._overlay then
        return self._overlay:remove(self)
    end
    self._disposed = true
    self:_finalize()
    return true
end

---@return boolean
function OverlayEntry:dispose()
    return self:remove()
end

---@param visible boolean
---@return boolean
function OverlayEntry:set_visible(visible)
    if self._disposed then
        return false
    end
    if type(visible) ~= 'boolean' then
        raise(std.TypeError('OverlayEntry.visible must be a boolean'))
    end
    if self.visible == visible then
        return false
    end
    self.visible = visible
    if self._overlay then
        self._overlay:_entry_changed(self)
    end
    return true
end

---@param opaque boolean
---@return boolean
function OverlayEntry:set_opaque(opaque)
    if self._disposed then
        return false
    end
    if type(opaque) ~= 'boolean' then
        raise(std.TypeError('OverlayEntry.opaque must be a boolean'))
    end
    if self.opaque == opaque then
        return false
    end
    self.opaque = opaque
    if self._overlay then
        self._overlay:_entry_changed(self)
    end
    return true
end

---@param maintain_state boolean
---@return boolean
function OverlayEntry:set_maintain_state(maintain_state)
    if self._disposed then
        return false
    end
    if type(maintain_state) ~= 'boolean' then
        raise(std.TypeError('OverlayEntry.maintain_state must be a boolean'))
    end
    if self.maintain_state == maintain_state then
        return false
    end
    self.maintain_state = maintain_state
    if self._overlay then
        self._overlay:_entry_changed(self)
    end
    return true
end

function OverlayEntry:mark_needs_build()
    if self._overlay then
        self._overlay:_entry_changed(self)
        return true
    end
    return false
end

---@param state OverlayState
function OverlayEntry:_attach(state)
    if self._disposed then
        raise(std.RuntimeError('cannot attach a disposed OverlayEntry'))
    end
    if self._overlay and self._overlay ~= state then
        raise(std.RuntimeError('OverlayEntry is already attached to an Overlay'))
    end
    self._overlay = state
end

function OverlayEntry:_detach(state)
    if self._overlay == state then
        self._overlay = nil
    end
end

function OverlayEntry:_set_mounted(mounted)
    self._mounted = mounted
end

--== mounted entry widget ===================================================

---@class _OverlayEntryWidgetOptions
---@field entry OverlayEntry
---@field paint_visible boolean
---@field key any?

---@class OverlayEntryWidget : StatefulWidget
---@field entry OverlayEntry
---@field paint_visible boolean
---@overload fun(options: _OverlayEntryWidgetOptions): self
local OverlayEntryWidget = std.class.new('OverlayEntryWidget', { StatefulWidget })

function OverlayEntryWidget:__init(options)
    if type(options) ~= 'table' then
        raise(std.TypeError('OverlayEntryWidget expects an options table'))
    end
    self.key = options.key or options.entry.key
    self.entry = options.entry
    self.paint_visible = options.paint_visible
    if not std.isinstance(self.entry, OverlayEntry) then
        raise(std.TypeError('OverlayEntryWidget.entry must be an OverlayEntry'))
    end
end

---@class OverlayEntryMountState : State
---@field entry OverlayEntry?
---@overload fun(): self
local OverlayEntryMountState = std.class.new('OverlayEntryMountState', { State })

function OverlayEntryMountState:__init()
    std.super(OverlayEntryMountState, self, State).__init(self)
    self.entry = nil
end

function OverlayEntryMountState:init_state()
    local entry = self.widget.entry --[[@as OverlayEntry]]
    self.entry = entry
    entry:_set_mounted(true)
end

function OverlayEntryMountState:did_update_widget(old_widget)
    local old = old_widget --[[@as OverlayEntryWidget]]
    local next_widget = self.widget --[[@as OverlayEntryWidget]]
    local next_entry = next_widget.entry
    if old.entry ~= next_entry then
        old.entry:_set_mounted(false)
        next_entry:_set_mounted(true)
        self.entry = next_entry
    end
end

function OverlayEntryMountState:dispose()
    if self.entry then
        local entry = self.entry
        entry:_set_mounted(false)
        local owner = self.context and self.context.owner
        if owner then
            owner:after_finalize(function()
                entry:_finalize()
            end)
        else
            entry:_finalize()
        end
        self.entry = nil
    end
end

function OverlayEntryMountState:build(context)
    local widget = self.widget --[[@as OverlayEntryWidget]]
    local child = widget.entry.builder(context)
    return Offstage({
        offstage = not widget.paint_visible,
        child = child,
    })
end

function OverlayEntryWidget:create_state()
    return OverlayEntryMountState()
end

--== scope ==================================================================

---@class _OverlayScopeOptions
---@field state OverlayState
---@field child Widget?
---@field key any?

---@class OverlayScope : InheritedWidget
---@field state OverlayState
---@field child Widget?
---@overload fun(options: _OverlayScopeOptions): self
local OverlayScope = std.class.new('OverlayScope', { InheritedWidget })
local OverlayScopeClass = OverlayScope --[[@as std.Class]]

function OverlayScope:__init(options)
    if type(options) ~= 'table' then
        raise(std.TypeError('OverlayScope expects an options table'))
    end
    self.key = options.key
    self.state = options.state
    self.child = options.child
    if self.state == nil then
        raise(std.TypeError('OverlayScope.state is required'))
    end
end

function OverlayScope:update_should_notify(old_widget)
    return self.state ~= old_widget.state
end

---@param context BuildContext
---@return OverlayState
function OverlayScope.of(context)
    if context == nil or type(context.depend_on_inherited_widget_of_exact_type) ~= 'function' then
        raise(std.TypeError('Overlay lookup expects a BuildContext'))
    end
    local scope = context:depend_on_inherited_widget_of_exact_type(OverlayScopeClass)
    if scope == nil then
        raise(std.RuntimeError('no Overlay ancestor was found'))
    end
    return scope.state
end

--== overlay ================================================================

---@class _OverlayOptions
---@field initial_entries OverlayEntry[]?
---@field on_plan fun(plan: OverlayPlan)?
---@field key any?

---@class Overlay : StatefulWidget
---@field initial_entries OverlayEntry[]
---@field on_plan fun(plan: OverlayPlan)?
---@overload fun(options?: _OverlayOptions): self
local Overlay = std.class.new('Overlay', { StatefulWidget })

function Overlay:__init(options)
    options = options or {}
    self.key = options.key
    self.initial_entries = copy_array(options.initial_entries)
    self.on_plan = options.on_plan
    if self.on_plan ~= nil and type(self.on_plan) ~= 'function' then
        raise(std.TypeError('Overlay.on_plan must be a function'))
    end
end

---@class OverlayPlanEntry
---@field entry OverlayEntry
---@field index integer
---@field visible boolean
---@field occluded boolean
---@field paint boolean
---@field input boolean
---@field mounted boolean

---@class OverlayPlan
---@field generation integer
---@field entries OverlayPlanEntry[]

---@class OverlayState : State
---@field entries OverlayEntry[]
---@field generation integer
---@field last_plan OverlayPlan?
---@overload fun(): self
local OverlayState = std.class.new('OverlayState', { State })

function OverlayState:__init()
    std.super(OverlayState, self, State).__init(self)
    self.entries = {}
    self.generation = 0
    self.last_plan = nil
end

function OverlayState:init_state()
    local widget = self.widget --[[@as Overlay]]
    for _, entry in ipairs(widget.initial_entries) do
        self:_attach_entry(entry)
    end
    self:_notify_plan()
end

function OverlayState:did_update_widget(old_widget)
    local widget = self.widget --[[@as Overlay]]
    self:_sync_initial_entries(widget.initial_entries)
    if old_widget.on_plan ~= widget.on_plan then
        self:_notify_plan()
    end
end

---@param entries OverlayEntry[]
function OverlayState:_sync_initial_entries(entries)
    entries = copy_array(entries)
    local seen = {}
    for _, entry in ipairs(entries) do
        if not std.isinstance(entry, OverlayEntry) then
            raise(std.TypeError('Overlay entries must be OverlayEntry values'))
        end
        if seen[entry] then
            raise(std.ValueError('Overlay entries cannot contain duplicates'))
        end
        seen[entry] = true
    end

    local current = {}
    for _, entry in ipairs(self.entries) do
        current[entry] = true
        if not seen[entry] then
            entry:_detach(self)
            entry:_mark_removed()
            if not entry:is_mounted() then
                entry:_finalize()
            end
        end
    end
    for _, entry in ipairs(entries) do
        if not current[entry] then
            entry:_attach(self)
        end
    end
    self.entries = entries
    self.generation = self.generation + 1
    self:_notify_plan()
end

---@param entry OverlayEntry
function OverlayState:_attach_entry(entry)
    if not std.isinstance(entry, OverlayEntry) then
        raise(std.TypeError('Overlay entries must be OverlayEntry values'))
    end
    entry:_attach(self)
    self.entries[#self.entries + 1] = entry
end

---@param entry OverlayEntry
---@return boolean
function OverlayState:insert(entry, index)
    if not std.isinstance(entry, OverlayEntry) then
        raise(std.TypeError('Overlay.insert expects an OverlayEntry'))
    end
    if entry:is_attached() then
        raise(std.RuntimeError('OverlayEntry is already attached to an Overlay'))
    end
    if index == nil then
        index = #self.entries + 1
    end
    if type(index) ~= 'number' or index < 1 or index > #self.entries + 1
        or index % 1 ~= 0 then
        raise(std.ValueError('Overlay.insert index must be an entry position'))
    end
    entry:_attach(self)
    table.insert(self.entries, index, entry)
    self:_changed()
    return true
end

---@param entry OverlayEntry
---@return boolean
function OverlayState:remove(entry)
    for index, current in ipairs(self.entries) do
        if current == entry then
            table.remove(self.entries, index)
            entry:_detach(self)
            entry:_mark_removed()
            if not entry:is_mounted() then
                entry:_finalize()
            end
            self:_changed()
            return true
        end
    end
    return false
end

---@param entries OverlayEntry[]
function OverlayState:rearrange(entries)
    entries = copy_array(entries)
    local seen = {}
    for _, entry in ipairs(entries) do
        if not std.isinstance(entry, OverlayEntry) or not entry:is_attached_to(self) then
            raise(std.ValueError('Overlay.rearrange expects attached OverlayEntry values'))
        end
        if seen[entry] then
            raise(std.ValueError('Overlay.rearrange cannot contain duplicates'))
        end
        seen[entry] = true
    end
    if #entries ~= #self.entries then
        raise(std.ValueError('Overlay.rearrange must include every attached entry'))
    end
    self.entries = entries
    self:_changed()
end

---@return OverlayEntry[]
function OverlayState:entries_snapshot()
    return copy_array(self.entries)
end

---@param entry OverlayEntry
function OverlayState:_entry_changed(entry)
    if entry:is_attached_to(self) then
        self:_changed()
    end
end

function OverlayState:_changed()
    self.generation = self.generation + 1
    self:_notify_plan()
    if self:is_mounted() then
        self:set_state()
    end
end

function OverlayState:_notify_plan()
    local occluded = false
    local status = {}
    for index = #self.entries, 1, -1 do
        local entry = self.entries[index]
        local paint = entry.visible and not occluded
        local keep = entry.visible or entry.maintain_state
        status[index] = {
            entry = entry,
            index = index,
            visible = entry.visible,
            occluded = occluded,
            paint = paint,
            input = paint,
            mounted = entry:is_mounted(),
            keep = keep,
        }
        if entry.visible and entry.opaque then
            occluded = true
        end
    end
    local entries = {}
    for index, item in ipairs(status) do
        item.keep = nil
        entries[#entries + 1] = item
    end
    local plan = { generation = self.generation, entries = entries }
    self.last_plan = plan
    local callback = self.widget and self.widget.on_plan
    if callback then
        callback(plan)
    end
end

function OverlayState:build()
    local occluded = false
    local children = {}
    for index = #self.entries, 1, -1 do
        local entry = self.entries[index]
        local paint_visible = entry.visible and not occluded
        if (entry.visible and not occluded) or entry.maintain_state then
            children[index] = OverlayEntryWidget({
                entry = entry,
                paint_visible = paint_visible,
                key = entry.key,
            })
        end
        if entry.visible and entry.opaque then
            occluded = true
        end
    end
    local ordered = {}
    for index = 1, #self.entries do
        if children[index] then
            ordered[#ordered + 1] = children[index]
        end
    end
    return OverlayScope({
        state = self,
        child = Stack({ children = ordered }),
    })
end

function OverlayState:dispose()
    local owner = self.context and self.context.owner
    for _, entry in ipairs(self.entries) do
        entry:_detach(self)
        entry:_mark_removed()
        if not entry:is_mounted() then
            if owner then
                owner:after_finalize(function()
                    entry:_finalize()
                end)
            else
                entry:_finalize()
            end
        end
    end
    self.entries = {}
    self.last_plan = nil
end

function Overlay:create_state()
    return OverlayState()
end

---@param context BuildContext
---@return OverlayState
function Overlay.of(context)
    return OverlayScope.of(context)
end

-- `Theatre` is the plan's semantic name for the one logical Overlay runtime;
-- it deliberately remains the same class object rather than a second facade.
local Theatre = Overlay

M.OverlayEntry = OverlayEntry
M.OverlayEntryWidget = OverlayEntryWidget
M.OverlayEntryMountState = OverlayEntryMountState
M.OverlayScope = OverlayScope
M.Overlay = Overlay
M.OverlayState = OverlayState
M.Theatre = Theatre

return M
