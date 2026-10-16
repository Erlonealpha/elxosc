-- Define-time Pages contribution registry and one-shot assembler.

local std = require 'elxlibs.std'
local region_mod = require 'player.region'
local scaffold_mod = require 'player.scaffold'
local widget_mod = require 'widget.widget'

local M = {}

local raise = std.raise
local PageWidget = widget_mod.Widget
local Region = region_mod.Region

---@alias PageOperation
---| 'fill'
---| 'append'

---@class PageContributionOptions
---@field key any?
---@field order number?
---@field scope_id string?
---@field op PageOperation?
---@field operation PageOperation?
---@field sequence integer?
---@field scope_sequence integer?

---@class PageContribution : std.object
---@field region RegionId
---@field widget Widget
---@field key any?
---@field order number?
---@field scope_id string?
---@field operation PageOperation
---@field op PageOperation
---@field sequence integer
---@field scope_sequence integer
---@overload fun(region: RegionId, widget: Widget, options?: PageContributionOptions): self
local PageContribution = std.class.new('PageContribution', {})

---@param region RegionId
---@param widget Widget
---@param options? PageContributionOptions
function PageContribution:__init(region, widget, options)
    options = options or {}
    self.region = region
    self.widget = widget
    self.key = options.key
    self.order = options.order
    self.scope_id = options.scope_id
    self.operation = options.operation or options.op or 'fill'
    self.op = self.operation
    self.sequence = options.sequence or 0
    self.scope_sequence = options.scope_sequence or 0
end

---@return PageContribution
function PageContribution:copy()
    return PageContribution(self.region, self.widget, {
        key = self.key,
        order = self.order,
        scope_id = self.scope_id,
        op = self.operation,
        operation = self.operation,
        sequence = self.sequence,
        scope_sequence = self.scope_sequence,
    })
end

---@class PagesRegistryOptions
---@field none boolean? reserved for a future explicit configuration object

---@class PageDiagnostic
---@field kind 'error'
---@field message string
---@field region RegionId|string
---@field operation string
---@field key any?
---@field scope_id string?
---@field sequence integer?
---@field conflict_sequence integer?

---@class PageSnapshot
---@field contributions PageContribution[]

---@class PagesRegistry : std.object
---@field _entries PageContribution[]
---@field _by_region table<string, PageContribution[]>
---@field _diagnostics PageDiagnostic[]
---@field _next_sequence integer
---@field _scope_sequences table<string, integer>
---@field _frozen boolean
---@field _snapshot PageSnapshot?
---@overload fun(options?: PagesRegistryOptions): self
local PagesRegistry = std.class.new('PagesRegistry', {})

local function copy_options(options)
    if options == nil then
        return {}
    end
    if type(options) ~= 'table' then
        raise(std.TypeError('pages contribution options must be a table'))
    end
    return {
        key = options.key,
        order = options.order,
        scope_id = options.scope_id,
        op = options.op,
        operation = options.operation,
    }
end

local function scope_label(scope_id)
    return scope_id or '<anonymous>'
end

local function value_label(value)
    if value == nil then
        return '<none>'
    end
    return tostring(value)
end

function PagesRegistry:__init()
    self._entries = {}
    self._by_region = {}
    self._diagnostics = {}
    self._next_sequence = 1
    self._scope_sequences = {}
    self._frozen = false
    self._snapshot = nil
end

---@param diagnostic PageDiagnostic
function PagesRegistry:_remember(diagnostic)
    local copy = {
        kind = diagnostic.kind,
        message = diagnostic.message,
        region = diagnostic.region,
        operation = diagnostic.operation,
        key = diagnostic.key,
        scope_id = diagnostic.scope_id,
        sequence = diagnostic.sequence,
        conflict_sequence = diagnostic.conflict_sequence,
    }
    self._diagnostics[#self._diagnostics + 1] = copy
end

---@param diagnostic PageDiagnostic
local function diagnostic_error(diagnostic)
    return string.format(
        "pages: scope '%s', region '%s', operation '%s', key '%s': %s",
        scope_label(diagnostic.scope_id),
        tostring(diagnostic.region),
        tostring(diagnostic.operation),
        value_label(diagnostic.key),
        diagnostic.message)
end

---@param region any
---@param operation string
---@param key any
---@param scope_id string?
---@param message string
---@param conflict_sequence integer?
---@return never
function PagesRegistry:_reject(region, operation, key, scope_id, message, conflict_sequence)
    local diagnostic = {
        kind = 'error',
        message = message,
        region = region,
        operation = operation,
        key = key,
        scope_id = scope_id,
        sequence = self._next_sequence,
        conflict_sequence = conflict_sequence,
    }
    self:_remember(diagnostic)
    raise(std.ValueError(diagnostic_error(diagnostic)))
end

---@param scope_id string?
---@return string?
local function validate_scope(scope_id)
    if scope_id ~= nil and (type(scope_id) ~= 'string' or scope_id == '') then
        raise(std.ValueError('pages: scope_id must be a non-empty string'))
    end
    return scope_id
end

---@param region any
---@param widget any
---@param options PageContributionOptions
---@param requested_operation 'add'|'fill'|'append'
---@param scope_id string?
---@return PageContribution
function PagesRegistry:_add(region, widget, options, requested_operation, scope_id)
    local key = options.key
    if self._frozen then
        self:_reject(region, requested_operation, key, scope_id,
            'the registry is frozen and accepts no more contributions')
    end

    local definition = region_mod.definition(region)
    if definition == nil then
        self:_reject(region, requested_operation, key, scope_id, 'unknown region')
    end
    if not definition.extension then
        self:_reject(region, requested_operation, key, scope_id,
            'the region is owned by the player and is not an extension slot')
    end
    if type(widget) ~= 'table' or not rawequal(rawget(widget, '__class'), PageWidget)
        and type(widget.create_element) ~= 'function' then
        self:_reject(region, requested_operation, key, scope_id, 'widget must be a Widget')
    end

    local operation = options.op or options.operation
    if operation == nil then
        if requested_operation == 'add' then
            operation = definition.cardinality == 'single' and 'fill' or 'append'
        else
            operation = requested_operation
        end
    end
    if requested_operation ~= 'add' and operation ~= requested_operation then
        self:_reject(region, tostring(operation), key, scope_id,
            string.format("%s() cannot use op '%s'", requested_operation, tostring(operation)))
    end
    if operation ~= 'fill' and operation ~= 'append' then
        self:_reject(region, operation, key, scope_id, 'operation must be fill or append')
    end
    if definition.cardinality == 'single' and operation ~= 'fill' then
        self:_reject(region, operation, key, scope_id,
            'single-child regions only accept fill')
    end
    if definition.cardinality == 'multi' and operation ~= 'append' then
        self:_reject(region, operation, key, scope_id,
            'multi-child regions only accept append')
    end
    if definition.cardinality == 'multi' and key == nil then
        self:_reject(region, operation, key, scope_id,
            'multi-child contributions require a key')
    end
    if type(key) == 'string' and key == '' then
        self:_reject(region, operation, key, scope_id, 'key must not be empty')
    end
    if options.order ~= nil and definition.cardinality ~= 'multi' then
        self:_reject(region, operation, key, scope_id,
            'order is only valid for multi-child regions')
    end
    if options.order ~= nil
        and (type(options.order) ~= 'number' or options.order ~= options.order
            or options.order == math.huge or options.order == -math.huge) then
        self:_reject(region, operation, key, scope_id, 'order must be a finite number')
    end

    local entry_scope = options.scope_id or scope_id
    if options.scope_id ~= nil and scope_id ~= nil and options.scope_id ~= scope_id then
        self:_reject(region, operation, key, scope_id,
            "options.scope_id does not match the registrar scope")
    end
    validate_scope(entry_scope)

    local entries = self._by_region[region]
    if entries == nil then
        entries = {}
        self._by_region[region] = entries
    end
    if definition.cardinality == 'single' and #entries > 0 then
        local previous = entries[1]
        self:_reject(region, operation, key, entry_scope,
            string.format("conflicts with scope '%s' registration sequence %d",
                scope_label(previous.scope_id), previous.sequence), previous.sequence)
    end
    if definition.cardinality == 'multi' then
        for _, previous in ipairs(entries) do
            if previous.key == key then
                self:_reject(region, operation, key, entry_scope,
                    string.format("duplicate key conflicts with scope '%s' registration sequence %d",
                        scope_label(previous.scope_id), previous.sequence), previous.sequence)
            end
        end
    end

    local sequence = self._next_sequence
    self._next_sequence = sequence + 1
    local scope_sequence = 0
    if entry_scope ~= nil then
        scope_sequence = (self._scope_sequences[entry_scope] or 0) + 1
        self._scope_sequences[entry_scope] = scope_sequence
    end
    local contribution = PageContribution(region, widget, {
        key = key,
        order = options.order,
        scope_id = entry_scope,
        op = operation,
        sequence = sequence,
        scope_sequence = scope_sequence,
    })
    self._entries[#self._entries + 1] = contribution
    entries[#entries + 1] = contribution
    return contribution:copy()
end

---@param region RegionId
---@param widget Widget
---@param options PageContributionOptions?
---@param scope_id string?
---@return PageContribution
function PagesRegistry:add(region, widget, options, scope_id)
    return self:_add(region, widget, copy_options(options), 'add', scope_id)
end

---@param region RegionId
---@param widget Widget
---@param options PageContributionOptions?
---@param scope_id string?
---@return PageContribution
function PagesRegistry:fill(region, widget, options, scope_id)
    return self:_add(region, widget, copy_options(options), 'fill', scope_id)
end

---@param region RegionId
---@param widget Widget
---@param options PageContributionOptions?
---@param scope_id string?
---@return PageContribution
function PagesRegistry:append(region, widget, options, scope_id)
    return self:_add(region, widget, copy_options(options), 'append', scope_id)
end

---@param scope_id string
---@return table
function PagesRegistry:scope(scope_id)
    validate_scope(scope_id)
    local registry = self
    return {
        add = function(_, region, widget, options)
            return registry:add(region, widget, options, scope_id)
        end,
        fill = function(_, region, widget, options)
            return registry:fill(region, widget, options, scope_id)
        end,
        append = function(_, region, widget, options)
            return registry:append(region, widget, options, scope_id)
        end,
    }
end

PagesRegistry.for_scope = PagesRegistry.scope

---@param left PageContribution
---@param right PageContribution
---@return boolean
local function contribution_before(left, right)
    if left.order == nil and right.order ~= nil then
        return false
    end
    if left.order ~= nil and right.order == nil then
        return true
    end
    if left.order ~= right.order then
        return left.order < right.order
    end
    return left.sequence < right.sequence
end

---@param entries PageContribution[]
---@return PageContribution[]
local function sorted_entries(entries)
    local result = {}
    for index, entry in ipairs(entries) do
        result[index] = entry:copy()
    end
    table.sort(result, contribution_before)
    return result
end

--- Freeze the initialization declaration set and return its immutable snapshot.
---@return PageSnapshot
function PagesRegistry:freeze()
    if self._snapshot ~= nil then
        return self:snapshot()
    end
    local contributions = {}
    for index, entry in ipairs(self._entries) do
        contributions[index] = entry:copy()
    end
    self._snapshot = { contributions = contributions }
    self._frozen = true
    return self:snapshot()
end

---@return boolean
function PagesRegistry:is_frozen()
    return self._frozen
end

---@return boolean
function PagesRegistry:is_sealed()
    return self._frozen
end

---@return PageSnapshot
function PagesRegistry:snapshot()
    local snapshot = self._snapshot
    if snapshot == nil then
        snapshot = self:freeze()
    end
    local contributions = {}
    for index, entry in ipairs(snapshot.contributions) do
        contributions[index] = entry:copy()
    end
    return { contributions = contributions }
end

--- Return pending or frozen contributions in registration order.
---@param region RegionId?
---@return PageContribution[]
function PagesRegistry:entries(region)
    local source = self._entries
    if self._snapshot ~= nil then
        source = self._snapshot.contributions
    end
    local result = {}
    for _, entry in ipairs(source) do
        if region == nil or entry.region == region then
            result[#result + 1] = entry:copy()
        end
    end
    return result
end

--- Return diagnostics generated by rejected registrations.
---@return PageDiagnostic[]
function PagesRegistry:diagnostics()
    local result = {}
    for index, diagnostic in ipairs(self._diagnostics) do
        result[index] = {
            kind = diagnostic.kind,
            message = diagnostic.message,
            region = diagnostic.region,
            operation = diagnostic.operation,
            key = diagnostic.key,
            scope_id = diagnostic.scope_id,
            sequence = diagnostic.sequence,
            conflict_sequence = diagnostic.conflict_sequence,
        }
    end
    return result
end

--- Assemble a fresh Root → PlayerScaffold → Main/grid/more Widget tree.
--- `options.middle_child` is a player-provided fallback for grid.middle;
--- a contribution to grid.middle takes precedence over that fallback.
---@param options? { middle_child?: Widget, key?: any, title_bar?: Widget,
---  timeline?: Widget, bottom?: Widget }
---@return PlayerScaffold
function PagesRegistry:assemble(options)
    options = options or {}
    local snapshot = self:freeze()
    local grid_widgets = {}
    local main_left = nil
    local main_right = nil
    local more_entries = {}
    local single_entries = {}

    for _, entry in ipairs(snapshot.contributions) do
        if entry.region == Region.MORE then
            more_entries[#more_entries + 1] = entry
        elseif entry.region == Region.MAIN_LEFT then
            main_left = entry.widget
        elseif entry.region == Region.MAIN_RIGHT then
            main_right = entry.widget
        else
            single_entries[entry.region] = entry.widget
        end
    end

    for _, region in ipairs(region_mod.grid_ids()) do
        grid_widgets[region] = single_entries[region]
    end
    local more_widgets = {}
    for _, entry in ipairs(sorted_entries(more_entries)) do
        more_widgets[#more_widgets + 1] = entry.widget
    end

    local middle_child = options.middle_child
    if grid_widgets[Region.GRID_MIDDLE] ~= nil then
        middle_child = grid_widgets[Region.GRID_MIDDLE]
        grid_widgets[Region.GRID_MIDDLE] = nil
    end

    return scaffold_mod.PlayerScaffold({
        key = options.key,
        region_widgets = grid_widgets,
        middle_child = middle_child,
        main_left = main_left,
        main_right = main_right,
        title_bar = options.title_bar,
        timeline = options.timeline,
        bottom = options.bottom,
        more_children = more_widgets,
    })
end

M.PageContribution = PageContribution
M.PagesRegistry = PagesRegistry

return M
