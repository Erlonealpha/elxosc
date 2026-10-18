-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Host-level presentation layers. Each layer owns a widget/render tree and an
-- ASS overlay, while all layers share one frame clock, scheduler and input
-- connection.

local mp = require 'mp'

local std = require 'elxlibs.std'
local geometry = require 'foundation.geometry'
local constraints_mod = require 'layout.constraints'
local scheduler_mod = require 'scheduler.scheduler'
local render_owner = require 'render.render_owner'
local ass_canvas = require 'backends.ass_canvas'
local ass_text_layout = require 'backends.ass_text_layout'
local text_layout = require 'text.text_layout'
local binding_mod = require 'widget.binding'
local pointer_event = require 'foundation.pointer_event'
local player_context = require 'widget.player_context'
local widget_app = require 'widget.app'
local theme_mod = require 'widget.theme'
local display_scope_mod = require 'widget.display_scope'
local text_style_mod = require 'text.text_style'
local mpv_app = require 'host.mpv_app'
local mpv_input = require 'host.mpv_input'

local Rect = geometry.Rect
local Constraints = constraints_mod.Constraints
local MpFrameClock = mpv_app.MpFrameClock
local Scheduler = scheduler_mod.Scheduler
local RenderOwner = render_owner.RenderOwner
local AssCanvas = ass_canvas.AssCanvas
local AssTextLayout = ass_text_layout.AssTextLayout
local WidgetBinding = binding_mod.WidgetBinding
local PointerEvent = pointer_event.PointerEvent
local MpvApp = widget_app.MpvApp
local ThemeData = theme_mod.ThemeData
local DisplaySnapshot = display_scope_mod.DisplaySnapshot
local TextStyle = text_style_mod.TextStyle
local PlayerStore = player_context.PlayerStore
local MpInput = mpv_input.MpInput
local raise = std.raise
---@type fun(value: any): OverlayZPolicy
local validate_z_policy
---@type fun(value: any): OverlayInputPolicy
local validate_input_policy
---@type fun(id: any)
local validate_id

local M = {}

---@alias OverlayZPolicy
---| 'main'
---| 'extension'
---| 'popup'
---| 'system'

---@alias OverlayInputPolicy
---| 'passive'
---| 'interactive'
---| 'exclusive'

---@alias OverlayLifecycle
---| 'registered'
---| 'mounted'
---| 'hidden'
---| 'disposed'

---@class OverlayHostOptions
---@field delay number?
---@field player_store PlayerStore?
---@field player_context MpPlayerContext?
---@field theme ThemeData?
---@field default_text_style TextStyle?
---@field display_snapshot DisplaySnapshot?
---@field on_pointer_move fun()?
---@field on_pointer_leave fun()?

---@class OverlayLayerOptions
---@field z_policy OverlayZPolicy?
---@field input_policy OverlayInputPolicy?
---@field visible boolean?
---@field opaque boolean?
---@field keep_alive boolean?
---@field binds BindRegistry?
---@field player_store PlayerStore?

---@class OverlayLayerDirty
---@field build boolean
---@field layout boolean
---@field paint boolean
---@field input boolean

---@class OverlayLayerCache
---@field ass_data string
---@field width number
---@field height number
---@field occluded boolean

---@class LayerRecord : std.object
---@field id string stable host-owned layer id
---@field registration_sequence integer
---@field root_widget Widget
---@field binds BindRegistry?
---@field player_store PlayerStore?
---@field z_policy OverlayZPolicy
---@field z number host-assigned presentation z
---@field input_policy OverlayInputPolicy
---@field visible boolean
---@field mounted boolean
---@field opaque boolean
---@field keep_alive boolean
---@field lifecycle OverlayLifecycle
---@field owner RenderOwner
---@field render_owner RenderOwner compatibility alias
---@field binding WidgetBinding?
---@field canvas AssCanvas
---@field presenter AssPresenter
---@field ass_presenter AssPresenter compatibility alias
---@field dirty OverlayLayerDirty
---@field cache OverlayLayerCache
---@field removed boolean
---@overload fun(id: string, root_widget: Widget, options: OverlayLayerOptions, sequence: integer, z: number): self
local LayerRecord = std.class.new('LayerRecord', {})

---@param id string
---@param root_widget Widget
---@param options OverlayLayerOptions
---@param sequence integer
---@param z number
function LayerRecord:__init(id, root_widget, options, sequence, z)
    self.id = id
    self.registration_sequence = sequence
    self.root_widget = root_widget
    self.binds = options.binds
    self.player_store = options.player_store
    self.z_policy = options.z_policy --[[@as OverlayZPolicy]]
    self.z = z
    self.input_policy = options.input_policy --[[@as OverlayInputPolicy]]
    self.visible = options.visible ~= false
    self.mounted = false
    self.opaque = options.opaque == true
    self.keep_alive = options.keep_alive ~= false
    self.lifecycle = 'registered'
    self.owner = RenderOwner()
    self.render_owner = self.owner
    self.binding = nil
    self.canvas = AssCanvas()
    self.presenter = nil
    self.ass_presenter = nil
    self.dirty = {
        build = true,
        layout = true,
        paint = true,
        input = true,
    }
    self.cache = {
        ass_data = '',
        width = -1,
        height = -1,
        occluded = false,
    }
    self.removed = false
end

---@class OverlayRegistry : std.object
---@field layers table<string, LayerRecord>
---@field order LayerRecord[] registration order
---@field _next_sequence integer
---@overload fun(): self
local OverlayRegistry = std.class.new('OverlayRegistry', {})

function OverlayRegistry:__init()
    self.layers = {}
    self.order = {}
    self._next_sequence = 0
end

---@return integer
function OverlayRegistry:next_sequence()
    self._next_sequence = self._next_sequence + 1
    return self._next_sequence
end

---@param layer LayerRecord
function OverlayRegistry:add(layer)
    if self.layers[layer.id] ~= nil then
        raise(std.ValueError('overlay layer id is already registered: ' .. layer.id))
    end
    self.layers[layer.id] = layer
    self.order[#self.order + 1] = layer
end

---@param id string
---@return LayerRecord?
function OverlayRegistry:get(id)
    return self.layers[id]
end

---@param id string
---@return LayerRecord?
function OverlayRegistry:remove(id)
    local layer = self.layers[id]
    if layer == nil then
        return nil
    end
    self.layers[id] = nil
    for index, candidate in ipairs(self.order) do
        if candidate == layer then
            table.remove(self.order, index)
            break
        end
    end
    return layer
end

---@return LayerRecord[]
function OverlayRegistry:records()
    local result = {}
    for index, layer in ipairs(self.order) do
        result[index] = layer
    end
    return result
end

---@return LayerRecord[]
function OverlayRegistry:sorted()
    local result = self:records()
    table.sort(result, function(left, right)
        if left.z == right.z then
            return left.registration_sequence < right.registration_sequence
        end
        return left.z < right.z
    end)
    return result
end

---@class OverlayDeclarationOptions
---@field z_policy OverlayZPolicy?
---@field input_policy OverlayInputPolicy?
---@field visible boolean?
---@field opaque boolean?
---@field keep_alive boolean?

---@class OverlayDeclaration : std.object
---@field id string
---@field root_widget Widget
---@field options OverlayDeclarationOptions
---@field scope_id string?
---@field sequence integer
---@overload fun(id: string, root_widget: Widget, options: OverlayDeclarationOptions,
---  scope_id: string?, sequence: integer): self
local OverlayDeclaration = std.class.new('OverlayDeclaration', {})

function OverlayDeclaration:__init(id, root_widget, options, scope_id, sequence)
    self.id = id
    self.root_widget = root_widget
    self.options = {}
    for name, value in pairs(options or {}) do
        self.options[name] = value
    end
    self.scope_id = scope_id
    self.sequence = sequence
end

function OverlayDeclaration:copy()
    return OverlayDeclaration(self.id, self.root_widget, self.options, self.scope_id, self.sequence)
end

---@class OverlayDeclarationRegistry : std.object
---@field _entries OverlayDeclaration[]
---@field _ids table<string, true>
---@field _next_sequence integer
---@field _snapshot OverlayDeclaration[]?
---@overload fun(): self
local OverlayDeclarationRegistry = std.class.new('OverlayDeclarationRegistry', {})

function OverlayDeclarationRegistry:__init()
    self._entries = {}
    self._ids = {}
    self._next_sequence = 0
    self._snapshot = nil
end

---@param id string
---@param root_widget Widget
---@param options OverlayDeclarationOptions?
---@param scope_id string?
function OverlayDeclarationRegistry:add(id, root_widget, options, scope_id)
    if self._snapshot ~= nil then
        raise(std.RuntimeError('overlay declarations are frozen'))
    end
    validate_id(id)
    if id == 'main' then
        raise(std.ValueError("overlay id 'main' is reserved for the player"))
    end
    if type(root_widget) ~= 'table' or type(root_widget.create_element) ~= 'function' then
        raise(std.ValueError('overlay root_widget must be a Widget'))
    end
    if self._ids[id] then
        raise(std.ValueError('overlay declaration id is already registered: ' .. id))
    end
    options = options or {}
    if type(options) ~= 'table' then
        raise(std.TypeError('overlay declaration options must be a table'))
    end
    local z_policy = options.z_policy or 'extension'
    if z_policy == 'main' or z_policy == 'system' then
        raise(std.ValueError('extension overlays may use extension or popup z_policy only'))
    end
    validate_z_policy(z_policy)
    local input_policy = options.input_policy or 'interactive'
    validate_input_policy(input_policy)
    local copied = {
        z_policy = z_policy,
        input_policy = input_policy,
        visible = options.visible,
        opaque = options.opaque,
        keep_alive = options.keep_alive,
    }
    self._next_sequence = self._next_sequence + 1
    local declaration = OverlayDeclaration(id, root_widget, copied, scope_id, self._next_sequence)
    self._ids[id] = true
    self._entries[#self._entries + 1] = declaration
    return declaration:copy()
end

function OverlayDeclarationRegistry:scope(scope_id)
    if type(scope_id) ~= 'string' or scope_id == '' then
        raise(std.ValueError('overlay scope_id must be a non-empty string'))
    end
    local registry = self
    return {
        add = function(_, id, root_widget, options)
            options = options or {}
            if options.scope_id ~= nil and options.scope_id ~= scope_id then
                raise(std.ValueError('overlay options.scope_id does not match the registrar scope'))
            end
            return registry:add(id, root_widget, options, scope_id)
        end,
    }
end

function OverlayDeclarationRegistry:freeze()
    if self._snapshot == nil then
        self._snapshot = {}
        for index, entry in ipairs(self._entries) do
            self._snapshot[index] = entry:copy()
        end
    end
    return self:snapshot()
end

function OverlayDeclarationRegistry:snapshot()
    local snapshot = self._snapshot or self:freeze()
    local result = {}
    for index, entry in ipairs(snapshot) do
        result[index] = entry:copy()
    end
    return result
end

---@class OverlayInputApp
---@field display Display
---@field owner OverlayInputRouter
---@field request_frame fun()

---@class OverlayInputRouter : std.object
---@field host OverlayHost
---@field capture_layer_id string?
---@overload fun(host: OverlayHost): self
local OverlayInputRouter = std.class.new('OverlayInputRouter', {})

function OverlayInputRouter:__init(host)
    self.host = host
    self.capture_layer_id = nil
end

---@param layer LayerRecord
---@return boolean
function OverlayInputRouter:_is_active(layer)
    return layer.mounted and layer.visible and not layer.removed
end

---@return LayerRecord[]
function OverlayInputRouter:_front_to_back()
    local records = self.host.registry:sorted()
    local result = {}
    for index = #records, 1, -1 do
        result[#result + 1] = records[index]
    end
    return result
end

---@return Rect
function OverlayInputRouter:_viewport_rect()
    local display = self.host.display
    return Rect(0, 0, display.width, display.height)
end

---@param region PointerRegion
---@param event_type PointerEventType
---@param point Offset?
---@return boolean
local function region_matches(region, event_type, point)
    if point == nil or not region.rect:contains(point) then
        return false
    end
    if event_type == 'wheel' then
        return region.wheel == true
    end
    return region.down == true
end

---@param layer LayerRecord
---@param event PointerEvent
---@return boolean
function OverlayInputRouter:_contains_event_region(layer, event)
    local point = event.point
    if point == nil then
        return false
    end
    for _, region in ipairs(layer.owner:pointer_regions()) do
        if region_matches(region, event.type, point) then
            return true
        end
    end
    return false
end

---@return PointerRegion[]
function OverlayInputRouter:pointer_regions()
    local regions = {}
    for _, layer in ipairs(self:_front_to_back()) do
        if self:_is_active(layer) and layer.input_policy ~= 'passive' then
            if layer.input_policy == 'exclusive' then
                regions[#regions + 1] = {
                    rect = self:_viewport_rect(),
                    down = true,
                    wheel = true,
                    layer_id = layer.id,
                }
            end
            for _, region in ipairs(layer.owner:pointer_regions()) do
                regions[#regions + 1] = {
                    rect = region.rect,
                    down = region.down,
                    wheel = region.wheel,
                    node = region.node,
                    layer_id = layer.id,
                }
            end
        end
    end
    return regions
end

---@param id string
---@return boolean
function OverlayInputRouter:has_layer_capture(id)
    if self.capture_layer_id ~= id then
        return false
    end
    local layer = self.host.registry:get(id)
    if layer == nil or not layer.mounted then
        self.capture_layer_id = nil
        return false
    end
    if not layer.owner:has_pointer_capture() then
        self.capture_layer_id = nil
        return false
    end
    return true
end

---@return boolean
function OverlayInputRouter:has_pointer_capture()
    local id = self.capture_layer_id
    if id == nil then
        return false
    end
    return self:has_layer_capture(id)
end

--- Cancel the active layer capture without allowing the event to fall through.
function OverlayInputRouter:cancel_capture()
    local id = self.capture_layer_id
    self.capture_layer_id = nil
    if id == nil then
        return
    end
    local layer = self.host.registry:get(id)
    if layer and layer.mounted then
        layer.owner:cancel_pointer()
    end
end

-- MpInput uses the RenderOwner name for this host-level operation.
function OverlayInputRouter:cancel_pointer()
    self:cancel_capture()
end

---@param id string
function OverlayInputRouter:cancel_layer_capture(id)
    if self.capture_layer_id == id then
        self:cancel_capture()
    end
end

--- Clear hover on every mounted layer. The owner also sends cancel to a
--- captured render node, so the host-level capture is cleared first.
function OverlayInputRouter:clear_hover()
    self.capture_layer_id = nil
    for _, layer in ipairs(self.host.registry:records()) do
        if layer.mounted then
            layer.owner:clear_hover()
        end
    end
end

---@param event PointerEvent|string
---@param point Offset?
---@param data any?
---@return DispatchResult
function OverlayInputRouter:dispatch_pointer_result(event, point, data)
    local pointer
    if type(event) == 'table' then
        if pointer_event.is_instance(event) then
            pointer = event --[[@as PointerEvent]]
        else
            pointer = PointerEvent(event --[[@as _PointerEventFields]])
        end
    else
        pointer = PointerEvent(event, point, data)
    end

    local captured_id = self.capture_layer_id
    if captured_id ~= nil then
        local captured = self.host.registry:get(captured_id)
        if captured == nil or not self:_is_active(captured) then
            self:cancel_capture()
            if pointer.type == 'up' or pointer.type == 'cancel' then
                return { handled = true, capture = false, stop_propagation = true }
            end
        else
            local result = captured.owner:dispatch_pointer_result(pointer)
            if pointer.type == 'up' or pointer.type == 'cancel' then
                if not captured.owner:has_pointer_capture() then
                    self.capture_layer_id = nil
                end
            end
            result.handled = true
            result.stop_propagation = true
            result.capture = self.capture_layer_id ~= nil
            return result
        end
    end

    ---@type LayerRecord?
    local selected = nil
    for _, layer in ipairs(self:_front_to_back()) do
        if self:_is_active(layer) and layer.input_policy ~= 'passive' then
            if layer.input_policy == 'exclusive'
                or self:_contains_event_region(layer, pointer) then
                selected = layer
                break
            end
        end
    end
    if selected == nil then
        -- A move outside every interactive layer is still meaningful: the
        -- RenderOwner must see it to emit leave events for any hovered node.
        -- MpInput only calls clear_hover when the pointer leaves the mpv
        -- window, so dropping an in-window move here leaves buttons hovered
        -- until another interactive region is entered.
        if pointer.type == 'move' then
            self:clear_hover()
        end
        return { handled = false, capture = false, stop_propagation = false }
    end
    ---@cast selected LayerRecord

    if pointer.type == 'move' then
        for _, layer in ipairs(self.host.registry:records()) do
            if layer ~= selected and layer.mounted then
                layer.owner:clear_hover()
            end
        end
    end

    local result = selected.owner:dispatch_pointer_result(pointer)
    if pointer.type == 'down' and result.capture then
        self.capture_layer_id = selected.id
    elseif (pointer.type == 'up' or pointer.type == 'cancel')
        and not selected.owner:has_pointer_capture() then
        self.capture_layer_id = nil
    end
    return result
end

---@class OverlayHost : std.object
---@field display Display
---@field clock MpFrameClock
---@field scheduler Scheduler
---@field registry OverlayRegistry
---@field input_router OverlayInputRouter
---@field input MpInput
---@field player_store PlayerStore?
---@field player_context MpPlayerContext?
---@field on_pointer_move fun()?
---@field on_pointer_leave fun()?
---@field _input_app OverlayInputApp
---@field _property_callbacks fun(name: string, value: any)[]
---@field _render_callback fun(dt: number, time: number)
---@field _shutdown_callback fun()
---@field _shutdown boolean
---@overload fun(options: OverlayHostOptions?): self
local OverlayHost = std.class.new('OverlayHost', {})

local Z_POLICIES = {
    main = 100,
    extension = 200,
    popup = 300,
    system = 1000,
}

local INPUT_POLICIES = {
    passive = true,
    interactive = true,
    exclusive = true,
}

---@param value any
---@return OverlayZPolicy
validate_z_policy = function(value)
    if type(value) ~= 'string' or Z_POLICIES[value] == nil then
        raise(std.ValueError('overlay z_policy must be main, extension, popup, or system'))
    end
    return value --[[@as OverlayZPolicy]]
end

---@param value any
---@return OverlayInputPolicy
validate_input_policy = function(value)
    if type(value) ~= 'string' or not INPUT_POLICIES[value] then
        raise(std.ValueError('overlay input_policy must be passive, interactive, or exclusive'))
    end
    return value --[[@as OverlayInputPolicy]]
end

---@param id any
validate_id = function(id)
    if type(id) ~= 'string' or id == '' then
        raise(std.ValueError('overlay layer id must be a non-empty string'))
    end
end

---@param options OverlayLayerOptions?
---@param defaults OverlayLayerOptions?
---@return OverlayLayerOptions
local function normalize_layer_options(options, defaults)
    options = options or {}
    if type(options) ~= 'table' then
        raise(std.TypeError('overlay layer options must be a table'))
    end
    if rawget(options, 'z') ~= nil then
        raise(std.ValueError('overlay layers accept z_policy, not arbitrary z'))
    end
    local result = {}
    result.z_policy = validate_z_policy(options.z_policy or (defaults and defaults.z_policy) or 'main')
    result.input_policy = validate_input_policy(
        options.input_policy or (defaults and defaults.input_policy) or 'passive')
    result.visible = options.visible
    if result.visible == nil and defaults then
        result.visible = defaults.visible
    end
    if result.visible == nil then
        result.visible = true
    end
    result.opaque = options.opaque
    if result.opaque == nil and defaults then
        result.opaque = defaults.opaque
    end
    if result.opaque == nil then
        result.opaque = false
    end
    result.keep_alive = options.keep_alive
    if result.keep_alive == nil and defaults then
        result.keep_alive = defaults.keep_alive
    end
    if result.keep_alive == nil then
        result.keep_alive = true
    end
    result.binds = options.binds
    if result.binds == nil and defaults then
        result.binds = defaults.binds
    end
    result.player_store = options.player_store
    if result.player_store == nil and defaults then
        result.player_store = defaults.player_store
    end
    return result
end

function OverlayHost:__init(options)
    options = options or {}
    if type(options) ~= 'table' then
        raise(std.TypeError('OverlayHost options must be a table'))
    end
    local config = {
        delay = options.delay,
        player_store = options.player_store or PlayerStore(),
        player_context = options.player_context,
    }
    if options.theme ~= nil and not std.isinstance(options.theme, ThemeData) then
        raise(std.TypeError('OverlayHost.theme must be a ThemeData'))
    end
    if options.default_text_style ~= nil
        and not std.isinstance(options.default_text_style, TextStyle) then
        raise(std.TypeError('OverlayHost.default_text_style must be a TextStyle'))
    end
    if options.display_snapshot ~= nil
        and not std.isinstance(options.display_snapshot, DisplaySnapshot) then
        raise(std.TypeError('OverlayHost.display_snapshot must be a DisplaySnapshot'))
    end
    self.player_store = config.player_store
    self.player_context = config.player_context
    self.theme = options.theme or ThemeData()
    self.default_text_style = options.default_text_style or TextStyle()
    self.on_pointer_move = options.on_pointer_move
    self.on_pointer_leave = options.on_pointer_leave
    self._shutdown = false
    self._property_callbacks = {}
    self.display_snapshot = options.display_snapshot or DisplaySnapshot({
        width = 1280,
        height = 720,
        initialized = false,
    })
    self.display = {
        width = self.display_snapshot.width,
        height = self.display_snapshot.height,
        initialized = self.display_snapshot.initialized,
    }
    self.clock = MpFrameClock(config.delay)
    self.scheduler = Scheduler(self.clock)
    self.registry = OverlayRegistry()
    self.input_router = OverlayInputRouter(self)
    self._input_app = {
        display = self.display,
        owner = self.input_router,
        request_frame = function()
            self:request_frame()
        end,
        on_pointer_move = function()
            if self.on_pointer_move then
                self.on_pointer_move()
            end
        end,
        on_pointer_leave = function()
            if self.on_pointer_leave then
                self.on_pointer_leave()
            end
        end,
    }

    self._render_callback = function(dt, time)
        self:render(dt, time)
    end
    self.scheduler:add_persistent(self._render_callback)
    text_layout.set_default(AssTextLayout())

    self:_observe()
    self:_update_display()
    self:_update_delay()
    self.input = MpInput(self._input_app --[[@as App]])
end

---@param root_widget Widget
---@param store PlayerStore?
---@return Widget
function OverlayHost:_wrap_root(root_widget, store)
    return MpvApp({
        child = root_widget,
        theme = self.theme,
        player_store = store or self.player_store,
        display_snapshot = self.display_snapshot,
        default_text_style = self.default_text_style,
    })
end

function OverlayHost:_observe()
    local dimensions_callback = function()
        self:_update_display()
    end
    local display_fps_callback = function()
        self:_update_delay()
    end
    local estimated_fps_callback = function()
        self:_update_delay()
    end
    mp.observe_property('osd-dimensions', 'native', dimensions_callback)
    mp.observe_property('display-fps', 'native', display_fps_callback)
    mp.observe_property('estimated-display-fps', 'native', estimated_fps_callback)
    self._property_callbacks = {
        dimensions_callback,
        display_fps_callback,
        estimated_fps_callback,
    }
    self._shutdown_callback = function()
        self:shutdown()
    end
    mp.register_event('shutdown', self._shutdown_callback)
end

function OverlayHost:_update_display()
    if self._shutdown then
        return
    end
    local width, height = mp.get_osd_size()
    if width <= 0 or height <= 0 then
        return
    end
    local changed = not self.display.initialized
        or self.display.width ~= width or self.display.height ~= height
    self.display.width, self.display.height = width, height
    self.display.initialized = true
    if changed then
        self.display_snapshot = self.display_snapshot:copy({
            width = width,
            height = height,
            initialized = true,
            generation = self.display_snapshot.generation + 1,
        })
        for _, layer in ipairs(self.registry:records()) do
            if layer.mounted and layer.binding then
                layer.binding:set_root_widget(self:_wrap_root(
                    layer.root_widget, layer.player_store))
            end
        end
    end
    local viewport = Constraints.tight(width, height)
    for _, layer in ipairs(self.registry:records()) do
        if layer.mounted then
            layer.owner:set_viewport(viewport)
            layer.dirty.layout = true
            layer.dirty.paint = true
        end
    end
    if self.input then
        self.input:update_regions()
        self:request_frame()
    end
end

function OverlayHost:_update_delay()
    if self._shutdown then
        return
    end
    local fps = mp.get_property_number('estimated-display-fps')
        or mp.get_property_number('display-fps')
    if fps and fps > 0 then
        self.clock:set_delay(1 / fps)
    end
end

function OverlayHost:request_frame()
    if self._shutdown then
        return
    end
    self.scheduler:schedule_frame()
end

---@param declarations OverlayDeclaration[]|{ contributions: OverlayDeclaration[] }
---@return LayerRecord[]
function OverlayHost:mount_declarations(declarations)
    if self._shutdown then
        raise(std.RuntimeError('OverlayHost is shut down'))
    end
    local entries = declarations
    if declarations and declarations.contributions then
        entries = declarations.contributions
    end
    local layers = {}
    for _, declaration in ipairs(entries or {}) do
        layers[#layers + 1] = self:create(
            declaration.id,
            declaration.root_widget,
            declaration.options)
    end
    return layers
end

---@param layer LayerRecord
function OverlayHost:_wire_layer(layer)
    layer.owner.on_dirty = function()
        layer.dirty.layout = layer.owner:needs_layout()
        layer.dirty.paint = layer.owner:needs_paint()
        self:request_frame()
    end
end

---@param layer LayerRecord
function OverlayHost:_mount_layer(layer)
    if layer.mounted then
        return
    end
    self:_wire_layer(layer)
    layer.binding = WidgetBinding(
        self:_wrap_root(layer.root_widget, layer.player_store),
        layer.owner,
        layer.binds,
        self.scheduler)
    layer.binding.on_dirty = function()
        layer.dirty.build = true
        self:request_frame()
    end
    if self.display.initialized then
        layer.owner:set_viewport(Constraints.tight(self.display.width, self.display.height))
    end
    layer.mounted = true
    layer.lifecycle = layer.visible and 'mounted' or 'hidden'
    layer.dirty.build = true
    layer.dirty.layout = true
    layer.dirty.paint = true
end

---@param layer LayerRecord
function OverlayHost:_dispose_layer_binding(layer)
    if layer.binding == nil then
        layer.mounted = false
        return
    end
    layer.binding.on_dirty = nil
    layer.binding:dispose()
    layer.binding = nil
    layer.mounted = false
    layer.owner.on_dirty = nil
    layer.dirty.build = false
    layer.dirty.layout = false
    layer.dirty.paint = false
end

---@param layer LayerRecord
---@param occluded boolean
function OverlayHost:_present_empty(layer, occluded)
    layer.canvas:reset()
    layer.presenter:present(layer.canvas, self.display.width, self.display.height)
    layer.cache.ass_data = ''
    layer.cache.width = self.display.width
    layer.cache.height = self.display.height
    layer.cache.occluded = occluded
end

---@param layer LayerRecord
function OverlayHost:_clear_output(layer)
    if layer.presenter then
        self:_present_empty(layer, false)
    end
end

---@param id string
function OverlayHost:_cancel_layer_capture(id)
    if self.input and self.input_router:has_layer_capture(id) then
        self.input:cancel_capture()
    end
end

---@param layer LayerRecord
---@param occluded boolean
function OverlayHost:_paint_layer(layer, occluded)
    if not layer.mounted or not layer.visible then
        return
    end
    if layer.cache.occluded ~= occluded then
        layer.cache.occluded = occluded
        if not occluded then
            layer.owner:mark_needs_paint()
        end
    end
    if occluded then
        if layer.cache.ass_data ~= '' then
            self:_present_empty(layer, true)
        end
        return
    end
    if not layer.owner:needs_paint() then
        return
    end
    layer.canvas:reset()
    layer.owner:paint(layer.canvas)
    layer.presenter:present(layer.canvas, self.display.width, self.display.height)
    layer.cache.ass_data = layer.canvas:text()
    layer.cache.width = self.display.width
    layer.cache.height = self.display.height
    layer.cache.occluded = false
    layer.dirty.paint = layer.owner:needs_paint()
end

---@return table<LayerRecord, boolean>
function OverlayHost:_occluded_layers()
    ---@type LayerRecord[]
    local visible = {}
    for _, layer in ipairs(self.registry:sorted()) do
        if layer.mounted and layer.visible then
            visible[#visible + 1] = layer
        end
    end
    local result = {}
    local blocked = false
    for index = #visible, 1, -1 do
        local layer = visible[index]
        if layer ~= nil then
            result[layer] = blocked
            if layer.opaque then
                blocked = true
            end
        end
    end
    return result
end

---@param dt number?
---@param time number?
function OverlayHost:render(dt, time)
    if self._shutdown or not self.display.initialized then
        return
    end
    for _, layer in ipairs(self.registry:records()) do
        if layer.mounted and layer.binding then
            layer.binding:flush_build()
            layer.dirty.build = false
            layer.dirty.layout = layer.owner:needs_layout()
            layer.dirty.paint = layer.owner:needs_paint()
        end
    end
    for _, layer in ipairs(self.registry:records()) do
        if layer.mounted and layer.visible then
            layer.owner:layout()
            layer.dirty.layout = layer.owner:needs_layout()
            layer.dirty.paint = layer.owner:needs_paint()
        end
    end
    self.input:update_regions()
    local occluded = self:_occluded_layers()
    for _, layer in ipairs(self.registry:sorted()) do
        self:_paint_layer(layer, occluded[layer] == true)
    end
end

---@param id string
---@param root_widget Widget
---@param options OverlayLayerOptions?
---@return LayerRecord
function OverlayHost:create(id, root_widget, options)
    if self._shutdown then
        raise(std.RuntimeError('OverlayHost is shut down'))
    end
    validate_id(id)
    if root_widget == nil then
        raise(std.ValueError('overlay root_widget is required'))
    end
    local config = normalize_layer_options(options, {
        player_store = self.player_store,
    })
    local sequence = self.registry:next_sequence()
    local layer = LayerRecord(id, root_widget, config, sequence, Z_POLICIES[config.z_policy])
    layer.presenter = mpv_app.AssPresenter(layer.z)
    layer.ass_presenter = layer.presenter
    self.registry:add(layer)
    self:_mount_layer(layer)
    if not layer.visible then
        if not layer.keep_alive then
            self:_dispose_layer_binding(layer)
        end
        self:_clear_output(layer)
    end
    self.input:update_regions()
    self:request_frame()
    return layer
end

---@param id string
---@param root_widget Widget
---@param options OverlayLayerOptions?
---@return LayerRecord?
function OverlayHost:update(id, root_widget, options)
    local layer = self.registry:get(id)
    if layer == nil then
        return nil
    end
    if root_widget == nil then
        raise(std.ValueError('overlay root_widget is required for update'))
    end
    local config = normalize_layer_options(options, {
        z_policy = layer.z_policy,
        input_policy = layer.input_policy,
        visible = layer.visible,
        opaque = layer.opaque,
        keep_alive = layer.keep_alive,
        binds = layer.binds,
        player_store = layer.player_store,
    })
    local root_changed = root_widget ~= layer.root_widget
    local binds_changed = config.binds ~= layer.binds
    local store_changed = config.player_store ~= layer.player_store
    if root_changed or binds_changed or store_changed then
        self:_cancel_layer_capture(id)
        layer.root_widget = root_widget
        layer.binds = config.binds
        layer.player_store = config.player_store
        if layer.mounted then
            self:_dispose_layer_binding(layer)
            self:_mount_layer(layer)
        end
    end
    layer.z_policy = config.z_policy --[[@as OverlayZPolicy]]
    layer.z = Z_POLICIES[layer.z_policy]
    if layer.presenter.overlay.z ~= layer.z then
        layer.presenter.overlay.z = layer.z
        layer.presenter.overlay:update()
    end
    if config.input_policy ~= layer.input_policy then
        self:_cancel_layer_capture(id)
        if layer.mounted then
            layer.owner:clear_hover()
        end
        layer.input_policy = config.input_policy --[[@as OverlayInputPolicy]]
    end
    layer.opaque = config.opaque == true
    layer.keep_alive = config.keep_alive ~= false
    if config.visible ~= layer.visible then
        if config.visible then
            self:show(id)
        else
            self:hide(id)
        end
    elseif not layer.visible and not layer.keep_alive and layer.mounted then
        self:_cancel_layer_capture(id)
        self:_dispose_layer_binding(layer)
    end
    self.input:update_regions()
    self:request_frame()
    return layer
end

---@param id string
---@param policy OverlayInputPolicy
---@return boolean
function OverlayHost:set_input_policy(id, policy)
    local layer = self.registry:get(id)
    if layer == nil then
        return false
    end
    policy = validate_input_policy(policy)
    if layer.input_policy == policy then
        return true
    end
    self:_cancel_layer_capture(id)
    if layer.mounted then
        layer.owner:clear_hover()
    end
    layer.input_policy = policy
    self.input:update_regions()
    self:request_frame()
    return true
end

---@param id string
---@return boolean
function OverlayHost:hide(id)
    local layer = self.registry:get(id)
    if layer == nil then
        return false
    end
    self:_cancel_layer_capture(id)
    if layer.mounted then
        layer.owner:clear_hover()
    end
    layer.visible = false
    if not layer.keep_alive then
        self:_dispose_layer_binding(layer)
    end
    layer.lifecycle = 'hidden'
    self:_clear_output(layer)
    self.input:update_regions()
    self:request_frame()
    return true
end

---@param id string
---@return boolean
function OverlayHost:show(id)
    local layer = self.registry:get(id)
    if layer == nil then
        return false
    end
    layer.visible = true
    if not layer.mounted then
        self:_mount_layer(layer)
    else
        layer.owner:mark_needs_paint()
        layer.dirty.paint = true
    end
    layer.lifecycle = 'mounted'
    self.input:update_regions()
    self:request_frame()
    return true
end

---@param id string
---@return boolean
function OverlayHost:remove(id)
    local layer = self.registry:get(id)
    if layer == nil then
        return false
    end
    self:_cancel_layer_capture(id)
    if layer.mounted then
        layer.owner:clear_hover()
    end
    layer.visible = false
    self:_clear_output(layer)
    self.input:update_regions()
    self:_dispose_layer_binding(layer)
    layer.owner.on_dirty = nil
    layer.presenter:remove()
    layer.mounted = false
    layer.removed = true
    layer.lifecycle = 'disposed'
    self.registry:remove(id)
    self.input:update_regions()
    self:request_frame()
    return true
end

---@return boolean
function OverlayHost:shutdown()
    if self._shutdown then
        return false
    end
    self._shutdown = true
    for _, callback in ipairs(self._property_callbacks) do
        mp.unobserve_property(callback)
    end
    self._property_callbacks = {}
    if self._shutdown_callback and mp.unregister_event then
        mp.unregister_event(self._shutdown_callback)
    end
    if self.input then
        self.input:shutdown()
    end
    for _, layer in ipairs(self.registry:records()) do
        self:_cancel_layer_capture(layer.id)
        self:_clear_output(layer)
        self:_dispose_layer_binding(layer)
        layer.owner.on_dirty = nil
        layer.presenter:remove()
        layer.visible = false
        layer.removed = true
        layer.lifecycle = 'disposed'
    end
    for _, layer in ipairs(self.registry:records()) do
        self.registry:remove(layer.id)
    end
    self.scheduler:remove_persistent(self._render_callback)
    self.scheduler:dispose()
    self.clock:dispose()
    if self.player_context then
        self.player_context:dispose()
    end
    return true
end

M.LayerRecord = LayerRecord
M.OverlayRegistry = OverlayRegistry
M.OverlayDeclaration = OverlayDeclaration
M.OverlayDeclarationRegistry = OverlayDeclarationRegistry
M.OverlayInputRouter = OverlayInputRouter
M.OverlayHost = OverlayHost
M.Z_POLICIES = {
    main = Z_POLICIES.main,
    extension = Z_POLICIES.extension,
    popup = Z_POLICIES.popup,
    system = Z_POLICIES.system,
}

return M
