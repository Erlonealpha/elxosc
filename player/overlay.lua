-- Host-independent logical overlay state.
--
-- This module deliberately stops at the logical boundary.  An OverlayEntry
-- may be connected to a lifecycle adapter, but the adapter owns any
-- WidgetBinding, Element, RenderOwner, presenter, or input implementation.
-- The core never stores a BuildContext.

local std = require 'elxlibs.std'
local navigation_mod = require 'player.navigation'

local raise = std.raise
local Page = navigation_mod.Page
local Route = navigation_mod.Route

local M = {}

---@alias OverlayEntryKind
---| 'main'
---| 'extension'
---| 'popup'
---| 'barrier'
---| 'system'

---@alias OverlaySurfacePolicy
---| 'default'
---| 'extension'
---| 'popup'
---| 'system'

---@alias LogicalOverlayInputPolicy
---| 'passive'
---| 'interactive'
---| 'exclusive'

---@alias OverlayEntryLifecycle
---| 'registered'
---| 'inserted'
---| 'mounted'
---| 'visible'
---| 'hidden'
---| 'occluded'
---| 'removed'
---| 'disposed'

---@alias OverlayLifecycleCallback fun(adapter: table, entry: OverlayEntry)

---@class OverlayLifecycleAdapter
---@field mount OverlayLifecycleCallback?
---@field unmount OverlayLifecycleCallback?
---@field hide OverlayLifecycleCallback?
---@field show OverlayLifecycleCallback?
---@field occlude OverlayLifecycleCallback?
---@field resume OverlayLifecycleCallback?
---@field remove OverlayLifecycleCallback?
---@field dispose OverlayLifecycleCallback?

---@param value any
---@param name string
local function copy_table(value, name)
    if value == nil then
        return nil
    end
    if type(value) ~= 'table' then
        raise(std.TypeError(name .. ' must be a table'))
    end
    local result = {}
    for key, item in pairs(value) do
        result[key] = item
    end
    return result
end

---@param value any
---@param name string
local function validate_boolean(value, name)
    if value ~= nil and type(value) ~= 'boolean' then
        raise(std.TypeError(name .. ' must be a boolean'))
    end
end

---@param value any
---@param name string
local function validate_input_policy(value, name)
    if value ~= 'passive' and value ~= 'interactive' and value ~= 'exclusive' then
        raise(std.ValueError(name .. ' must be passive, interactive or exclusive'))
    end
end

---@param value any
---@param name string
local function validate_surface_policy(value, name)
    if value ~= 'default' and value ~= 'extension' and value ~= 'popup'
        and value ~= 'system' then
        raise(std.ValueError(name .. ' must be default, extension, popup or system'))
    end
end

---@param value any
---@param name string
local function validate_adapter(value, name)
    if value ~= nil and type(value) ~= 'table' then
        raise(std.TypeError(name .. ' must be a lifecycle adapter table'))
    end
    if value then
        for method_name, callback in pairs(value) do
            if callback ~= nil and type(callback) ~= 'function'
                and (method_name == 'mount' or method_name == 'unmount'
                    or method_name == 'hide' or method_name == 'show'
                    or method_name == 'occlude' or method_name == 'resume'
                    or method_name == 'remove' or method_name == 'dispose') then
                raise(std.TypeError(name .. '.' .. method_name .. ' must be a function'))
            end
        end
    end
end

---@param kind OverlayEntryKind
---@return OverlaySurfacePolicy
local function default_surface_for(kind)
    if kind == 'main' then
        return 'default'
    end
    if kind == 'extension' then
        return 'extension'
    end
    if kind == 'system' then
        return 'system'
    end
    return 'popup'
end

---@param kind OverlayEntryKind
---@return integer
local function kind_order(kind)
    if kind == 'main' then
        return 1
    end
    if kind == 'extension' then
        return 2
    end
    if kind == 'system' then
        return 4
    end
    return 3
end

---@class OverlayEntryOptions
---@field key any?
---@field id any? compatibility alias for key
---@field child any? logical content descriptor
---@field builder (fun(context: BuildContext): any?)?
---@field kind OverlayEntryKind?
---@field entry_kind OverlayEntryKind? compatibility alias for kind
---@field surface_policy OverlaySurfacePolicy?
---@field surface OverlaySurfacePolicy? compatibility alias for surface_policy
---@field opaque boolean?
---@field maintain_state boolean?
---@field keep_alive boolean? compatibility alias for maintain_state
---@field visible boolean?
---@field input_policy LogicalOverlayInputPolicy?
---@field lifecycle_adapter OverlayLifecycleAdapter?
---@field route PopupRoute?
---@field role 'barrier'|'content'?
---@field paired_entry OverlayEntry?
---@field on_remove fun(entry: OverlayEntry)?
---@field on_dispose fun(entry: OverlayEntry)?

---@class OverlayEntry : std.object
---@field key any?
---@field child any? logical content descriptor
---@field builder (fun(context: BuildContext): any?)?
---@field kind OverlayEntryKind
---@field surface_policy OverlaySurfacePolicy
---@field opaque boolean
---@field maintain_state boolean
---@field visible boolean
---@field input_policy LogicalOverlayInputPolicy
---@field lifecycle_adapter OverlayLifecycleAdapter?
---@field route PopupRoute?
---@field role 'barrier'|'content'?
---@field paired_entry OverlayEntry?
---@field registration_sequence integer?
---@field lifecycle OverlayEntryLifecycle
---@field mounted boolean
---@field removed boolean
---@field disposed boolean
---@field owner Overlay?
---@overload fun(options?: OverlayEntryOptions): self
local OverlayEntry = std.class.new('OverlayEntry', {})

---@param options OverlayEntryOptions?
function OverlayEntry:__init(options)
    options = options or {}
    if type(options) ~= 'table' then
        raise(std.TypeError('OverlayEntry expects an options table'))
    end

    local kind = options.kind or options.entry_kind or 'popup'
    if kind ~= 'main' and kind ~= 'extension' and kind ~= 'popup'
        and kind ~= 'barrier' and kind ~= 'system' then
        raise(std.ValueError('OverlayEntry.kind is invalid'))
    end

    local surface_policy = options.surface_policy or options.surface
        or default_surface_for(kind)
    validate_surface_policy(surface_policy, 'OverlayEntry.surface_policy')

    local input_policy = options.input_policy
        or (kind == 'barrier' and 'exclusive' or 'interactive')
    validate_input_policy(input_policy, 'OverlayEntry.input_policy')
    validate_boolean(options.opaque, 'OverlayEntry.opaque')
    validate_boolean(options.maintain_state, 'OverlayEntry.maintain_state')
    validate_boolean(options.keep_alive, 'OverlayEntry.keep_alive')
    validate_boolean(options.visible, 'OverlayEntry.visible')
    if options.builder ~= nil and type(options.builder) ~= 'function' then
        raise(std.TypeError('OverlayEntry.builder must be a function'))
    end
    validate_adapter(options.lifecycle_adapter, 'OverlayEntry.lifecycle_adapter')

    self.key = options.key ~= nil and options.key or options.id
    self.child = options.child
    self.builder = options.builder
    self.kind = kind --[[@as OverlayEntryKind]]
    self.surface_policy = surface_policy --[[@as OverlaySurfacePolicy]]
    self.opaque = options.opaque == true
    if options.maintain_state ~= nil then
        self.maintain_state = options.maintain_state
    elseif options.keep_alive ~= nil then
        self.maintain_state = options.keep_alive
    else
        self.maintain_state = kind == 'main' or kind == 'extension'
    end
    self.visible = options.visible ~= false
    self.input_policy = input_policy --[[@as LogicalOverlayInputPolicy]]
    self.lifecycle_adapter = options.lifecycle_adapter
    self.route = options.route
    self.role = options.role
    self.paired_entry = options.paired_entry
    self.registration_sequence = nil
    self.lifecycle = 'registered'
    self.mounted = false
    self.removed = false
    self.disposed = false
    self._on_remove = options.on_remove
    self._on_dispose = options.on_dispose
end

---@param method_name string
---@param ... any
function OverlayEntry:_call_adapter(method_name, ...)
    local adapter = self.lifecycle_adapter
    local callback = adapter and adapter[method_name]
    if callback then
        callback(adapter, self, ...)
    end
end

---@param overlay Overlay?
function OverlayEntry:_invalidate(overlay)
    overlay = overlay or self.owner
    if overlay then
        overlay:_invalidate()
    end
end

---@return boolean
function OverlayEntry:_mount()
    if self.mounted or self.disposed or self.removed then
        return self.mounted
    end
    self:_call_adapter('mount')
    self.mounted = true
    return true
end

---@return boolean
function OverlayEntry:_unmount()
    if not self.mounted then
        return false
    end
    self:_call_adapter('unmount')
    self.mounted = false
    return true
end

---@param overlay Overlay
function OverlayEntry:_inserted(overlay)
    if self.owner ~= nil then
        raise(std.ValueError('OverlayEntry already belongs to an Overlay'))
    end
    if self.disposed or self.removed or self.lifecycle == 'removed'
        or self.lifecycle == 'disposed' then
        raise(std.RuntimeError('disposed OverlayEntry cannot be inserted'))
    end
    self.owner = overlay
    self.lifecycle = 'inserted'
    if self.visible or self.maintain_state then
        self:_mount()
    end
    if self.visible then
        self.lifecycle = 'visible'
    else
        self.lifecycle = 'hidden'
    end
end

---@param reason string
function OverlayEntry:_removed(reason)
    if self.disposed or self.removed then
        return
    end
    self:_unmount()
    self:_call_adapter('remove', reason)
    self.visible = false
    self.removed = true
    self.lifecycle = 'removed'
    if self._on_remove then
        self._on_remove(self)
    end
    self:dispose()
end

---@return boolean
function OverlayEntry:mount()
    if self.disposed or self.removed then
        return false
    end
    if self.owner == nil then
        raise(std.RuntimeError('OverlayEntry.mount requires an inserted entry'))
    end
    local mounted = self:_mount()
    if self.visible then
        self.lifecycle = 'visible'
    elseif self.lifecycle ~= 'occluded' then
        self.lifecycle = 'hidden'
    end
    return mounted
end

---@return boolean
function OverlayEntry:hide()
    if self.disposed or self.removed or not self.visible then
        return false
    end
    self.visible = false
    self:_call_adapter('hide')
    if not self.maintain_state then
        self:_unmount()
    end
    self.lifecycle = 'hidden'
    self:_invalidate()
    return true
end

---@return boolean
function OverlayEntry:show()
    if self.disposed or self.removed or self.visible then
        return false
    end
    self.visible = true
    if not self.mounted then
        self:_mount()
    end
    self:_call_adapter('show')
    self.lifecycle = 'visible'
    self:_invalidate()
    return true
end

---@param visible boolean
---@return boolean changed
function OverlayEntry:set_visible(visible)
    validate_boolean(visible, 'OverlayEntry.visible')
    if visible then
        return self:show()
    end
    return self:hide()
end

---@return boolean
function OverlayEntry:is_visible()
    return self.visible and not self.removed and not self.disposed
end

---@return boolean
function OverlayEntry:is_mounted()
    return self.mounted and not self.removed and not self.disposed
end

---@param opaque boolean
---@return boolean changed
function OverlayEntry:set_opaque(opaque)
    validate_boolean(opaque, 'OverlayEntry.opaque')
    if self.opaque == opaque then
        return false
    end
    self.opaque = opaque
    self:_invalidate()
    return true
end

---@param input_policy LogicalOverlayInputPolicy
---@return boolean changed
function OverlayEntry:set_input_policy(input_policy)
    validate_input_policy(input_policy, 'OverlayEntry.input_policy')
    if self.input_policy == input_policy then
        return false
    end
    self.input_policy = input_policy
    self:_invalidate()
    return true
end

---@param maintain_state boolean
---@return boolean changed
function OverlayEntry:set_maintain_state(maintain_state)
    validate_boolean(maintain_state, 'OverlayEntry.maintain_state')
    if self.maintain_state == maintain_state then
        return false
    end
    self.maintain_state = maintain_state
    self:_invalidate()
    return true
end

---@param surface_policy OverlaySurfacePolicy
---@return boolean changed
function OverlayEntry:set_surface_policy(surface_policy)
    validate_surface_policy(surface_policy, 'OverlayEntry.surface_policy')
    if self.surface_policy == surface_policy then
        return false
    end
    self.surface_policy = surface_policy
    self:_invalidate()
    return true
end

---@param child any
---@param builder fun(context: BuildContext): any?
function OverlayEntry:set_content(child, builder)
    if builder ~= nil and type(builder) ~= 'function' then
        raise(std.TypeError('OverlayEntry.builder must be a function'))
    end
    self.child = child
    self.builder = builder
    self:_invalidate()
end

---@return boolean
function OverlayEntry:remove()
    if self.owner then
        return self.owner:remove(self)
    end
    return false
end

---@return boolean
function OverlayEntry:dispose()
    if self.disposed then
        return false
    end
    if not self.removed then
        return false
    end
    self:_call_adapter('dispose')
    self.disposed = true
    self.lifecycle = 'disposed'
    self.owner = nil
    if self._on_dispose then
        self._on_dispose(self)
    end
    return true
end

---@param lifecycle_adapter OverlayLifecycleAdapter
function OverlayEntry:set_lifecycle_adapter(lifecycle_adapter)
    validate_adapter(lifecycle_adapter, 'OverlayEntry.lifecycle_adapter')
    if self.mounted then
        raise(std.RuntimeError('cannot replace a mounted OverlayEntry adapter'))
    end
    self.lifecycle_adapter = lifecycle_adapter
end

---@param result any
---@return boolean
function OverlayEntry:activate(result)
    if self.disposed or self.removed or not self.visible
        or self.input_policy == 'passive' then
        return false
    end
    if self.role == 'barrier' and self.child
        and type(self.child.dismiss) == 'function' then
        return self.child:dismiss(result)
    end
    return false
end

---@class OverlayPlanEntry
---@field entry OverlayEntry
---@field key any?
---@field kind OverlayEntryKind
---@field surface_policy OverlaySurfacePolicy
---@field registration_sequence integer
---@field visible boolean
---@field mounted boolean
---@field opaque boolean
---@field maintain_state boolean
---@field input_policy LogicalOverlayInputPolicy
---@field occluded boolean
---@field paintable boolean
---@field input_active boolean
---@field blocks_input boolean
---@field lifecycle OverlayEntryLifecycle

---@class PresentationPlan
---@field generation integer
---@field entries OverlayPlanEntry[] back-to-front logical order
---@field ordered_entries OverlayEntry[] back-to-front logical order
---@field paint_entries OverlayEntry[] back-to-front paintable entries
---@field input_entries OverlayEntry[] front-to-back input order

---@class OverlayOptions
---@field entries OverlayEntry[]?

---@class Overlay : std.object
---@field _entries OverlayEntry[] registration records
---@field _next_sequence integer
---@field _generation integer
---@field _plan PresentationPlan?
---@field _plan_dirty boolean
---@overload fun(options?: OverlayOptions): self
local Overlay = std.class.new('Overlay', {})

---@param options OverlayOptions?
function Overlay:__init(options)
    options = options or {}
    if type(options) ~= 'table' then
        raise(std.TypeError('Overlay expects an options table'))
    end
    self._entries = {}
    self._next_sequence = 0
    self._generation = 0
    self._plan = nil
    self._plan_dirty = true
    if options.entries ~= nil then
        if type(options.entries) ~= 'table' then
            raise(std.TypeError('Overlay.entries must be an array'))
        end
        for _, entry in ipairs(options.entries) do
            self:insert(entry)
        end
    end
end

function Overlay:_invalidate()
    self._generation = self._generation + 1
    self._plan_dirty = true
end

---@return integer
function Overlay:generation()
    return self._generation
end

---@return integer
function Overlay:plan_generation()
    return self._generation
end

---@param entry OverlayEntry
---@return boolean
function Overlay:insert(entry)
    if not std.isinstance(entry, OverlayEntry) then
        raise(std.TypeError('Overlay.insert expects an OverlayEntry'))
    end
    if entry.owner ~= nil then
        raise(std.ValueError('OverlayEntry already belongs to an Overlay'))
    end
    for _, candidate in ipairs(self._entries) do
        if entry.key ~= nil and candidate.key == entry.key then
            raise(std.ValueError('OverlayEntry key is already registered'))
        end
    end
    self._next_sequence = self._next_sequence + 1
    entry.registration_sequence = self._next_sequence
    entry:_inserted(self)
    self._entries[#self._entries + 1] = entry
    self:_invalidate()
    return true
end

---@param entry OverlayEntry
---@return boolean
function Overlay:register(entry)
    return self:insert(entry)
end

---@param entry OverlayEntry
---@return boolean
function Overlay:hide(entry)
    if not std.isinstance(entry, OverlayEntry) or entry.owner ~= self then
        return false
    end
    return entry:hide()
end

---@param entry OverlayEntry
---@return boolean
function Overlay:show(entry)
    if not std.isinstance(entry, OverlayEntry) or entry.owner ~= self then
        return false
    end
    return entry:show()
end

---@return OverlayEntry[]
function Overlay:ordered_entries()
    local result = {}
    for index, entry in ipairs(self._entries) do
        result[index] = entry
    end
    table.sort(result, function(left, right)
        local left_order = kind_order(left.kind)
        local right_order = kind_order(right.kind)
        if left_order == right_order then
            return (left.registration_sequence or 0) < (right.registration_sequence or 0)
        end
        return left_order < right_order
    end)
    return result
end

---@return OverlayEntry[]
function Overlay:entries()
    return self:ordered_entries()
end

---@param key any
---@return OverlayEntry?
function Overlay:get(key)
    for _, entry in ipairs(self._entries) do
        if entry.key == key then
            return entry
        end
    end
    return nil
end

---@param entry OverlayEntry
---@return boolean
function Overlay:_remove_one(entry)
    local found = nil
    for index, candidate in ipairs(self._entries) do
        if candidate == entry then
            found = index
            break
        end
    end
    if not found then
        return false
    end
    table.remove(self._entries, found)
    entry:_removed('remove')
    return true
end

---@param entry OverlayEntry
---@return boolean
function Overlay:remove(entry)
    if not std.isinstance(entry, OverlayEntry) or entry.owner ~= self then
        return false
    end
    local pair = entry.paired_entry
    local removed = self:_remove_one(entry)
    if pair and pair.owner == self then
        removed = self:_remove_one(pair) or removed
    end
    if removed then
        self:_invalidate()
    end
    return removed
end

---@param entries OverlayEntry[]
function Overlay:_remove_entries(entries)
    local removed = false
    for index = #entries, 1, -1 do
        local entry = entries[index]
        if entry.owner == self then
            removed = self:_remove_one(entry) or removed
        end
    end
    if removed then
        self:_invalidate()
    end
end

---@param route PopupRoute
---@return boolean
function Overlay:remove_route(route)
    if type(route) ~= 'table' or type(route.overlay_entries) ~= 'function' then
        raise(std.TypeError('Overlay.remove_route expects a PopupRoute'))
    end
    local entries = route:overlay_entries()
    self:_remove_entries(entries)
    return #entries > 0
end

---@return PresentationPlan
function Overlay:plan()
    if not self._plan_dirty and self._plan then
        return self._plan
    end

    local ordered = self:ordered_entries()
    local records = {}
    local covered = false
    for index = #ordered, 1, -1 do
        local entry = ordered[index]
        local occluded = covered and entry.visible
        if occluded then
            if entry.lifecycle ~= 'occluded' then
                entry:_call_adapter('occlude')
                if not entry.maintain_state then
                    entry:_unmount()
                end
                if entry.lifecycle ~= 'hidden' then
                    entry.lifecycle = 'occluded'
                end
            end
        elseif entry.visible then
            if entry.lifecycle == 'occluded' then
                if not entry.mounted then
                    entry:_mount()
                end
                entry:_call_adapter('resume')
            end
            if entry.lifecycle ~= 'hidden' then
                entry.lifecycle = 'visible'
            end
        end

        local record = {
            entry = entry,
            key = entry.key,
            kind = entry.kind,
            surface_policy = entry.surface_policy,
            registration_sequence = entry.registration_sequence,
            visible = entry.visible,
            mounted = entry.mounted,
            opaque = entry.opaque,
            maintain_state = entry.maintain_state,
            input_policy = entry.input_policy,
            occluded = occluded,
            paintable = entry.visible and not occluded,
            input_active = false,
            blocks_input = false,
            lifecycle = entry.lifecycle,
        }
        records[index] = record
        if entry.visible and entry.opaque then
            covered = true
        end
    end

    local input_entries = {}
    local input_blocked = false
    for index = #records, 1, -1 do
        local record = records[index]
        local barrier = record.entry.role == 'barrier'
        local eligible = record.visible and record.input_policy ~= 'passive'
            and (not record.occluded or barrier)
        if eligible and not input_blocked then
            record.input_active = true
            record.blocks_input = record.input_policy == 'exclusive'
            input_entries[#input_entries + 1] = record.entry
            if record.blocks_input then
                input_blocked = true
            end
        end
    end

    local paint_entries = {}
    for _, record in ipairs(records) do
        if record.paintable then
            paint_entries[#paint_entries + 1] = record.entry
        end
    end

    self._plan = {
        generation = self._generation,
        entries = records,
        ordered_entries = ordered,
        paint_entries = paint_entries,
        input_entries = input_entries,
    }
    self._plan_dirty = false
    return self._plan
end

---@return PresentationPlan
function Overlay:presentation_plan()
    return self:plan()
end

---@param route PopupRoute
---@return OverlayEntry[]
function Overlay:insert_route(route)
    if type(route) ~= 'table' or type(route.overlay_entries) ~= 'function' then
        raise(std.TypeError('Overlay.insert_route expects a PopupRoute'))
    end
    route:attach_overlay(self)
    return route:overlay_entries()
end

---@return boolean
function Overlay:dispose()
    local entries = self:ordered_entries()
    local disposed = false
    for index = #entries, 1, -1 do
        disposed = self:remove(entries[index]) or disposed
    end
    return disposed
end

---@class TheatreOptions
---@field overlay Overlay?
---@field main any? Widget or OverlayEntry
---@field extension any? Widget or OverlayEntry
---@field main_entry OverlayEntry?
---@field extension_entry OverlayEntry?

---@class Theatre : std.object
---@field overlay Overlay
---@field main_entry OverlayEntry?
---@field extension_entry OverlayEntry?
---@overload fun(options?: TheatreOptions): self
local Theatre = std.class.new('Theatre', {})

---@param value any
---@param kind OverlayEntryKind
---@param key string
---@return OverlayEntry?
local function stable_entry(value, kind, key)
    if value == nil then
        return nil
    end
    if std.isinstance(value, OverlayEntry) then
        if value.kind ~= kind then
            raise(std.ValueError('Theatre stable entry kind does not match ' .. kind))
        end
        return value
    end
    return OverlayEntry({
        key = key,
        child = value,
        kind = kind,
        surface_policy = default_surface_for(kind),
        maintain_state = true,
    })
end

---@param options TheatreOptions?
function Theatre:__init(options)
    options = options or {}
    if type(options) ~= 'table' then
        raise(std.TypeError('Theatre expects an options table'))
    end
    self.overlay = (options.overlay or Overlay()) --[[@as Overlay]]
    if not std.isinstance(self.overlay, Overlay) then
        raise(std.TypeError('Theatre.overlay must be an Overlay'))
    end
    self.main_entry = stable_entry(options.main_entry or options.main, 'main', 'main')
    self.extension_entry = stable_entry(
        options.extension_entry or options.extension,
        'extension',
        'extension')
    if self.main_entry then
        self.overlay:insert(self.main_entry)
    end
    if self.extension_entry then
        self.overlay:insert(self.extension_entry)
    end
end

---@return OverlayEntry[]
function Theatre:entries()
    return self.overlay:entries()
end

---@param entry OverlayEntry
---@return boolean
function Theatre:insert(entry)
    return self.overlay:insert(entry)
end

---@param entry OverlayEntry
---@return boolean
function Theatre:remove(entry)
    return self.overlay:remove(entry)
end

---@param entry OverlayEntry
---@return boolean
function Theatre:hide(entry)
    return self.overlay:hide(entry)
end

---@param entry OverlayEntry
---@return boolean
function Theatre:show(entry)
    return self.overlay:show(entry)
end

---@return PresentationPlan
function Theatre:plan()
    return self.overlay:plan()
end

---@return PresentationPlan
function Theatre:presentation_plan()
    return self.overlay:presentation_plan()
end

---@return integer
function Theatre:generation()
    return self.overlay:generation()
end

---@param route PopupRoute
---@return OverlayEntry[]
function Theatre:push(route)
    return self.overlay:insert_route(route)
end

---@param route PopupRoute
---@return boolean
function Theatre:remove_route(route)
    if route._overlay == self.overlay then
        route:detach_overlay()
        return true
    end
    return false
end

---@class ModalBarrierOptions
---@field key any?
---@field dismissible boolean?
---@field opaque boolean?
---@field enabled boolean?
---@field present boolean?
---@field surface_policy OverlaySurfacePolicy?
---@field on_dismiss (fun(result: any?): boolean?)?

---@class ModalBarrier : std.object
---@field key any?
---@field dismissible boolean
---@field opaque boolean
---@field surface_policy OverlaySurfacePolicy
---@field on_dismiss (fun(result: any?): boolean?)?
---@field visible boolean
---@field entry OverlayEntry?
---@overload fun(options?: ModalBarrierOptions): self
local ModalBarrier = std.class.new('ModalBarrier', {})

---@param options ModalBarrierOptions?
function ModalBarrier:__init(options)
    options = options or {}
    if type(options) ~= 'table' then
        raise(std.TypeError('ModalBarrier expects an options table'))
    end
    validate_boolean(options.dismissible, 'ModalBarrier.dismissible')
    validate_boolean(options.opaque, 'ModalBarrier.opaque')
    if options.on_dismiss ~= nil and type(options.on_dismiss) ~= 'function' then
        raise(std.TypeError('ModalBarrier.on_dismiss must be a function'))
    end
    local surface_policy = options.surface_policy or 'popup'
    validate_surface_policy(surface_policy, 'ModalBarrier.surface_policy')
    self.key = options.key
    self.dismissible = options.dismissible ~= false
    self.opaque = options.opaque == true
    self.surface_policy = surface_policy --[[@as OverlaySurfacePolicy]]
    self.on_dismiss = options.on_dismiss
    self.visible = true
    self.entry = nil
end

---@param result any
---@return boolean
function ModalBarrier:dismiss(result)
    if not self.visible or not self.dismissible then
        return false
    end
    if self.on_dismiss then
        local accepted = self.on_dismiss(result)
        if accepted == false then
            return false
        end
    end
    return true
end

---@param visible boolean
function ModalBarrier:set_visible(visible)
    validate_boolean(visible, 'ModalBarrier.visible')
    if self.visible == visible then
        return
    end
    self.visible = visible
    if self.entry then
        if visible then
            self.entry:show()
        else
            self.entry:hide()
        end
    end
end

---@class PopupRouteOptions
---@field barrier ModalBarrier?
---@field content_input_policy LogicalOverlayInputPolicy?
---@field content_surface_policy OverlaySurfacePolicy?

---@class PopupRoute : Route
---@field barrier ModalBarrier?
---@field barrier_entry OverlayEntry?
---@field content_entry OverlayEntry
---@field _overlay Overlay?
---@field _overlay_entries OverlayEntry[]
---@field navigator NavigatorState?
---@field content_mounted boolean
---@overload fun(page: Page, options?: PopupRouteOptions): self
local PopupRoute = std.class.new('PopupRoute', { Route })

---@param page Page
---@param options PopupRouteOptions?
function PopupRoute:__init(page, options)
    if not std.isinstance(page, Page) then
        raise(std.TypeError('PopupRoute expects a Page'))
    end
    if page.route_kind ~= 'popup' then
        raise(std.ValueError('PopupRoute requires a Page with route_kind popup'))
    end
    options = options or {}
    if type(options) ~= 'table' then
        raise(std.TypeError('PopupRoute options must be a table'))
    end
    std.super(PopupRoute, self, Route).__init(self, page)
    self._overlay = nil
    self._overlay_entries = {}
    self:_configure_entries(page, options)
end

---@param page Page
---@param options PopupRouteOptions?
function PopupRoute:_configure_entries(page, options)
    options = options or {}
    self.barrier = nil
    self.barrier_entry = nil

    local barrier_config = page.barrier_config
    if options.barrier ~= nil then
        if not std.isinstance(options.barrier, ModalBarrier) then
            raise(std.TypeError('PopupRoute.barrier must be a ModalBarrier'))
        end
        self.barrier = options.barrier
    elseif barrier_config ~= nil and barrier_config ~= false then
        if std.isinstance(barrier_config, ModalBarrier) then
            self.barrier = barrier_config
        else
            local config = copy_table(barrier_config, 'Page.barrier_config')
                --[[@as ModalBarrierOptions]]
            if config and config.enabled ~= false and config.present ~= false then
                self.barrier = ModalBarrier(config)
            end
        end
    end

    local surface_policy = options.content_surface_policy
        or page.surface_policy or 'popup'
    if type(surface_policy) == 'table' then
        surface_policy = surface_policy.name or surface_policy.surface or 'popup'
    end
    validate_surface_policy(surface_policy, 'PopupRoute.content_surface_policy')
    local input_policy = options.content_input_policy or page.input_policy or 'interactive'
    validate_input_policy(input_policy, 'PopupRoute.content_input_policy')

    self.content_entry = OverlayEntry({
        key = page.key or self,
        child = page,
        builder = page.builder,
        kind = 'popup',
        surface_policy = surface_policy,
        opaque = page.opaque,
        maintain_state = page.maintain_state,
        input_policy = input_policy,
        route = self,
        role = 'content',
    })
    if self.content_entry.maintain_state == nil then
        self.content_entry.maintain_state = false
    end
    if self.barrier then
        local barrier_entry = OverlayEntry({
            key = self,
            child = self.barrier,
            kind = 'barrier',
            surface_policy = self.barrier.surface_policy,
            opaque = self.barrier.opaque,
            maintain_state = false,
            input_policy = 'exclusive',
            visible = self.barrier.visible,
            route = self,
            role = 'barrier',
        })
        self.barrier_entry = barrier_entry
        self.barrier.entry = barrier_entry
        self.barrier_entry.paired_entry = self.content_entry
        self.content_entry.paired_entry = self.barrier_entry
    end
    self._overlay_entries = {}
    if self.barrier_entry then
        self._overlay_entries[#self._overlay_entries + 1] = self.barrier_entry
    end
    self._overlay_entries[#self._overlay_entries + 1] = self.content_entry

    if self.barrier then
        local barrier_callback = self.barrier.on_dismiss
        self.barrier.on_dismiss = function(result)
            if barrier_callback then
                local accepted = barrier_callback(result)
                if accepted == false then
                    return false
                end
            end
            return self:request_pop(result)
        end
    end
end

---@param page Page
function PopupRoute:update_page(page)
    if not std.isinstance(page, Page) or page.route_kind ~= 'popup' then
        raise(std.TypeError('PopupRoute.page must remain a popup Page'))
    end
    local attached = self._overlay
    if attached then
        self:detach_overlay()
    end
    std.super(PopupRoute, self, Route).update_page(self, page)
    self:_configure_entries(page)
    if attached then
        self:attach_overlay(attached)
    end
end

---@return OverlayEntry[]
function PopupRoute:overlay_entries()
    local result = {}
    for index, entry in ipairs(self._overlay_entries) do
        result[index] = entry
    end
    return result
end

---@param overlay Overlay
---@return boolean
function PopupRoute:attach_overlay(overlay)
    if not std.isinstance(overlay, Overlay) then
        raise(std.TypeError('PopupRoute.attach_overlay expects an Overlay'))
    end
    if self._overlay and self._overlay ~= overlay then
        raise(std.ValueError('PopupRoute already belongs to an Overlay'))
    end
    if self._overlay == overlay then
        return false
    end
    local inserted = {}
    local ok, err = pcall(function()
        for _, entry in ipairs(self._overlay_entries) do
            overlay:insert(entry)
            inserted[#inserted + 1] = entry
        end
    end)
    if not ok then
        for index = #inserted, 1, -1 do
            overlay:_remove_one(inserted[index])
        end
        error(err, 0)
    end
    self._overlay = overlay
    return true
end

function PopupRoute:detach_overlay()
    if not self._overlay then
        return false
    end
    local overlay = self._overlay
    self._overlay = nil
    overlay:_remove_entries(self._overlay_entries)
    return true
end

---@param result any
---@return boolean
function PopupRoute:request_pop(result)
    if self.navigator and self.navigator.current_route
        and self.navigator:current_route() == self then
        return self.navigator:pop(result)
    end
    return self:begin_pop(result)
end

function PopupRoute:dispose()
    if self.content_mounted then
        return std.super(PopupRoute, self, Route).dispose(self)
    end
    self:detach_overlay()
    return std.super(PopupRoute, self, Route).dispose(self)
end

M.OverlayEntry = OverlayEntry
M.Overlay = Overlay
M.Theatre = Theatre
M.ModalBarrier = ModalBarrier
M.PopupRoute = PopupRoute

return M
