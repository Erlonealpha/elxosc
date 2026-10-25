-- This file is part of elxosc and is released under the terms of the MIT license.
-- Copyright (C) 2026 ErloneAlpha

-- Initialization-only Widget composition.
--
-- A SlotWrap is a declaration in the input Widget description.  The
-- CompositionAssembler resolves it into a fresh Widget description before the
-- tree is mounted.  SlotWrap must therefore never become part of the mounted
-- runtime tree in the production Define path.

local std = require 'elxlibs.std'
local widget_mod = require 'widget.widget'

local Widget = widget_mod.Widget
local StatelessWidget = widget_mod.StatelessWidget
local raise = std.raise

local M = {}

---@alias SlotOperation 'replace'|'set'|'append'

---@alias SlotPosition 'first'|'last'|table<string, string>

local function copy_value(value)
    if type(value) ~= 'table' or std.kindof(value) ~= nil then
        return value
    end
    local result = {}
    for key, nested in pairs(value) do
        result[key] = copy_value(nested)
    end
    return result
end

local function is_operation(value)
    return value == 'replace' or value == 'set' or value == 'append'
end

---@class SlotSpecOptions
---@field id string
---@field allow SlotOperation[]|table<SlotOperation, boolean>?
---@field default_op SlotOperation?
---@field default_opts table<string, any>?
---@field default_value Widget|Widget[]?
---@field builder? fun(value: Widget|Widget[]|nil, opts: table<string, any>?): Widget?
---@field append_limit integer?
---@field identity? fun(opts: table<string, any>, contribution: Contribution): string?
---@field validate? fun(value: Widget, opts: table<string, any>, contribution: Contribution): boolean|string

---@class SlotSpec : std.object
---@field id string
---@field allow table<SlotOperation, true>
---@field default_op SlotOperation?
---@field default_opts table<string, any>
---@field default_value Widget|Widget[]?
---@field builder fun(value: Widget|Widget[]|nil, opts: table<string, any>?): Widget?
---@field append_limit integer?
---@field identity fun(opts: table<string, any>, contribution: Contribution): string?
---@field validate? fun(value: Widget, opts: table<string, any>, contribution: Contribution): boolean|string
---@overload fun(options: SlotSpecOptions): self
local SlotSpec = std.class.new('SlotSpec', {})

local function copy_table(source)
    local result = {}
    for key, value in pairs(source or {}) do
        result[key] = copy_value(value)
    end
    return result
end

local function normalize_allow(allow, default_op)
    local result = {}
    if type(allow) == 'table' then
        for key, value in pairs(allow) do
            if type(key) == 'number' then
                if type(value) ~= 'string' then
                    raise(std.TypeError('SlotSpec.allow entries must be operation names'))
                end
                if not is_operation(value) then
                    raise(std.ValueError(string.format("unknown Slot operation '%s'", value)))
                end
                result[value] = true
            elseif value then
                if type(key) ~= 'string' then
                    raise(std.TypeError('SlotSpec.allow keys must be operation names'))
                end
                if not is_operation(key) then
                    raise(std.ValueError(string.format("unknown Slot operation '%s'", key)))
                end
                result[key] = true
            end
        end
    elseif allow ~= nil then
        raise(std.TypeError('SlotSpec.allow must be an array or operation set'))
    end
    if next(result) == nil and default_op ~= nil then
        result[default_op] = true
    end
    return result
end

function SlotSpec:__init(options)
    options = options or {}
    if type(options.id) ~= 'string' or options.id == '' then
        raise(std.ValueError('SlotSpec.id must be a non-empty string'))
    end
    if options.builder ~= nil and type(options.builder) ~= 'function' then
        raise(std.TypeError('SlotSpec.builder must be a function'))
    end
    if options.append_limit ~= nil
        and (type(options.append_limit) ~= 'number' or options.append_limit < 0
            or options.append_limit % 1 ~= 0) then
        raise(std.ValueError('SlotSpec.append_limit must be a non-negative integer'))
    end

    self.id = options.id
    if options.default_op ~= nil and not is_operation(options.default_op) then
        raise(std.ValueError(string.format(
            "unknown Slot operation '%s'", tostring(options.default_op))))
    end
    self.allow = normalize_allow(options.allow, options.default_op)
    self.default_op = options.default_op
    if self.default_op ~= nil and not self.allow[self.default_op] then
        raise(std.ValueError(string.format(
            "SlotSpec.default_op '%s' is not allowed", self.default_op)))
    end
    if self.default_op == nil then
        local only
        for operation in pairs(self.allow) do
            if only ~= nil then
                only = false
                break
            end
            only = operation
        end
        if type(only) == 'string' then
            self.default_op = only
        end
    end
    self.default_opts = copy_table(options.default_opts)
    self.default_value = copy_value(options.default_value)
    self.builder = options.builder or function(value)
        return value --[[@as Widget?]]
    end
    self.append_limit = options.append_limit
    self.identity = options.identity
    self.validate = options.validate
end

---@param operation SlotOperation
---@return boolean
function SlotSpec:allows(operation)
    return self.allow[operation] == true
end

---@param value Widget|Widget[]|nil
---@param opts table<string, any>?
---@return Widget?
function SlotSpec:build(value, opts)
    local result = self.builder(value, opts)
    if result ~= nil and not std.isinstance(result, Widget) then
        raise(std.TypeError(string.format(
            "SlotSpec '%s' builder must return a Widget or nil", self.id)))
    end
    return result
end

---@class SlotWrap : StatelessWidget
---@field spec SlotSpec
---@field default_value Widget|Widget[]?
---@overload fun(spec: SlotSpec, default_value: Widget|Widget[]?): self
local SlotWrap = std.class.new('SlotWrap', { StatelessWidget })

function SlotWrap:__init(spec, default_value)
    if not std.isinstance(spec, SlotSpec) then
        raise(std.TypeError('SlotWrap.spec must be a SlotSpec'))
    end
    self.key = nil
    self.spec = spec
    self.default_value = default_value == nil and copy_value(spec.default_value)
        or copy_value(default_value)
end

function SlotWrap:child_widgets()
    local value = self.default_value
    if value == nil then
        return {}
    end
    if std.isinstance(value, Widget) then
        return { value }
    end
    if type(value) ~= 'table' then
        return {}
    end
    local children = {}
    for _, child in ipairs(value) do
        if child ~= nil then
            children[#children + 1] = child
        end
    end
    return children
end

function SlotWrap:build()
    return self.spec:build(self.default_value)
end

---@class Contribution : std.object
---@field slot_id string
---@field widget Widget
---@field op SlotOperation?
---@field opts table<string, any>
---@field scope_id string
---@field sequence integer
---@field scope_sequence integer
---@overload fun(slot_id: string, widget: Widget, op: SlotOperation?, opts: table<string, any>?, scope_id: string, sequence: integer, scope_sequence: integer): self
local Contribution = std.class.new('Contribution', {})

function Contribution:__init(slot_id, widget, op, opts, scope_id, sequence, scope_sequence)
    if type(slot_id) ~= 'string' or slot_id == '' then
        raise(std.ValueError('Contribution.slot_id must be a non-empty string'))
    end
    if not std.isinstance(widget, Widget) then
        raise(std.TypeError('Contribution.widget must be a Widget'))
    end
    if op ~= nil and op ~= 'replace' and op ~= 'set' and op ~= 'append' then
        raise(std.ValueError(string.format("unknown Slot operation '%s'", tostring(op))))
    end
    self.slot_id = slot_id
    self.widget = widget
    self.op = op
    self.opts = copy_table(opts)
    self.scope_id = scope_id or '<anonymous>'
    self.sequence = sequence
    self.scope_sequence = scope_sequence
end

---@class ContributionRegistry : std.object
---@field _entries Contribution[]
---@field _scope_sequences table<string, integer>
---@field _next_sequence integer
---@field _sealed boolean
---@field _snapshot Contribution[]?
---@overload fun(): self
local ContributionRegistry = std.class.new('ContributionRegistry', {})

function ContributionRegistry:__init()
    self._entries = {}
    self._scope_sequences = {}
    self._next_sequence = 0
    self._sealed = false
    self._snapshot = nil
end

---@return ContributionRegistry
function ContributionRegistry:fork()
    local child = ContributionRegistry()
    child._next_sequence = self._next_sequence
    for scope_id, sequence in pairs(self._scope_sequences) do
        child._scope_sequences[scope_id] = sequence
    end
    for _, contribution in ipairs(self._entries) do
        child._entries[#child._entries + 1] = Contribution(
            contribution.slot_id,
            contribution.widget,
            contribution.op,
            contribution.opts,
            contribution.scope_id,
            contribution.sequence,
            contribution.scope_sequence)
    end
    return child
end

---@param transaction ContributionRegistry
function ContributionRegistry:commit_from(transaction)
    if self._sealed then
        raise(std.RuntimeError('contributions are sealed'))
    end
    for index = #self._entries + 1, #transaction._entries do
        local contribution = transaction._entries[index]
        self._entries[#self._entries + 1] = Contribution(
            contribution.slot_id,
            contribution.widget,
            contribution.op,
            contribution.opts,
            contribution.scope_id,
            contribution.sequence,
            contribution.scope_sequence)
    end
    self._next_sequence = transaction._next_sequence
    for scope_id, sequence in pairs(transaction._scope_sequences) do
        self._scope_sequences[scope_id] = sequence
    end
end

---@param scope_id string
function ContributionRegistry:remove_scope(scope_id)
    if self._sealed then
        raise(std.RuntimeError('contributions are sealed'))
    end
    local kept = {}
    for _, contribution in ipairs(self._entries) do
        if contribution.scope_id ~= scope_id then
            kept[#kept + 1] = contribution
        end
    end
    self._entries = kept
end

---@param scope_id string
function ContributionRegistry:clear_scope(scope_id)
    self:remove_scope(scope_id)
end

---@param slot_id string
---@param widget Widget
---@param opts table<string, any>?
---@param scope_id string?
---@return Contribution
function ContributionRegistry:add(slot_id, widget, opts, scope_id)
    if self._sealed then
        raise(std.RuntimeError('contributions are sealed'))
    end
    if type(slot_id) ~= 'string' or slot_id == '' then
        raise(std.ValueError('bind slot id must be a non-empty string'))
    end
    if not std.isinstance(widget, Widget) then
        raise(std.TypeError('bind value must be a Widget'))
    end
    if opts ~= nil and type(opts) ~= 'table' then
        raise(std.TypeError('bind opts must be a table'))
    end
    ---@type SlotOperation?
    local operation = opts and opts.op or nil
    if operation ~= nil and operation ~= 'replace' and operation ~= 'set'
        and operation ~= 'append' then
        raise(std.ValueError(string.format("unknown Slot operation '%s'", tostring(operation))))
    end
    local owner = scope_id or '<anonymous>'
    local scope_sequence = (self._scope_sequences[owner] or 0) + 1
    self._scope_sequences[owner] = scope_sequence
    self._next_sequence = self._next_sequence + 1
    local contribution = Contribution(
        slot_id,
        widget,
        operation,
        opts,
        owner,
        self._next_sequence,
        scope_sequence)
    self._entries[#self._entries + 1] = contribution
    return contribution
end

---@return Contribution[]
function ContributionRegistry:snapshot()
    local source = self._snapshot or self._entries
    local result = {}
    for _, contribution in ipairs(source) do
        result[#result + 1] = Contribution(
            contribution.slot_id,
            contribution.widget,
            contribution.op,
            contribution.opts,
            contribution.scope_id,
            contribution.sequence,
            contribution.scope_sequence)
    end
    return result
end

---@return Contribution[]
function ContributionRegistry:seal()
    if not self._sealed then
        self._sealed = true
        self._snapshot = self:snapshot()
    end
    return self:snapshot()
end

---@return boolean
function ContributionRegistry:is_sealed()
    return self._sealed
end

---@return Contribution[]
function ContributionRegistry:entries()
    return self:snapshot()
end

---@param slot_id string
---@return Contribution[]
function ContributionRegistry:get(slot_id)
    local result = {}
    for _, contribution in ipairs(self._entries) do
        if contribution.slot_id == slot_id then
            result[#result + 1] = contribution
        end
    end
    return result
end

---@return Contribution[]
function ContributionRegistry:entries_for_scope(scope_id)
    local result = {}
    for _, contribution in ipairs(self._entries) do
        if contribution.scope_id == scope_id then
            result[#result + 1] = contribution
        end
    end
    return result
end

---@class CompositionAssembler : std.object
---@field contributions Contribution[]
---@field diagnostics table[]
---@field on_warning fun(diagnostic: table)?
---@field _used table<Contribution, true>
---@overload fun(contributions: Contribution[]?, options: { on_warning: fun(diagnostic: table)? }?): self
local CompositionAssembler = std.class.new('CompositionAssembler', {})

local function widget_copy(widget)
    local clone = widget.__class:__new()
    local source = rawget(widget --[[@as table]], '__dict') or {}
    local target = rawget(clone --[[@as table]], '__dict') or {}
    for key, value in pairs(source) do
        target[key] = copy_value(value)
    end
    return clone
end

local function widget_array(value)
    return type(value) == 'table' and not std.isinstance(value, Widget)
end

local function copy_child_value(value, replacements)
    if replacements[value] ~= nil then
        return replacements[value]
    end
    if not widget_array(value) then
        return value
    end
    local changed = false
    local copy = {}
    for key, item in pairs(value) do
        local replacement = replacements[item]
        if replacement ~= nil then
            copy[key] = replacement
            changed = true
        else
            copy[key] = item
        end
    end
    return changed and copy or value
end

local function merge_options(defaults, supplied)
    local result = copy_table(defaults)
    for key, value in pairs(supplied or {}) do
        result[key] = value
    end
    return result
end

function CompositionAssembler:__init(contributions, options)
    options = options or {}
    self.contributions = contributions or {}
    self.diagnostics = {}
    self.on_warning = options.on_warning
    self._used = {}
end

function CompositionAssembler:_warn(slot_id, message, contribution)
    local diagnostic = {
        level = 'warning',
        slot_id = slot_id,
        message = message,
        scope_id = contribution and contribution.scope_id or nil,
        sequence = contribution and contribution.sequence or nil,
    }
    self.diagnostics[#self.diagnostics + 1] = diagnostic
    if self.on_warning then
        self.on_warning(diagnostic)
    end
end

function CompositionAssembler:_matching(spec)
    local result = {}
    for _, contribution in ipairs(self.contributions) do
        if contribution.slot_id == spec.id then
            result[#result + 1] = contribution
            self._used[contribution] = true
        end
    end
    return result
end

function CompositionAssembler:_normalize(spec, contribution)
    local operation = contribution.op or spec.default_op
    if operation == nil then
        self:_warn(spec.id, 'contribution has no operation and SlotSpec has no default', contribution)
        return nil
    end
    if not spec:allows(operation) then
        self:_warn(spec.id, string.format("operation '%s' is not allowed", operation), contribution)
        return nil
    end
    if operation == 'append' and contribution.opts.key ~= nil then
        self:_warn(spec.id, 'callers cannot set append identity/key', contribution)
        return nil
    end
    local opts = merge_options(spec.default_opts, contribution.opts)
    opts.op = nil
    if opts.priority ~= nil and type(opts.priority) ~= 'number' then
        self:_warn(spec.id, 'append priority must be numeric', contribution)
        return nil
    end
    if spec.validate ~= nil then
        local ok, result = pcall(spec.validate, contribution.widget, opts, contribution)
        if not ok or result == false then
            self:_warn(spec.id, type(result) == 'string' and result or 'contribution failed validation', contribution)
            return nil
        end
    end
    return {
        contribution = contribution,
        widget = contribution.widget,
        operation = operation,
        opts = opts,
    }
end

local function sort_by_priority(items)
    table.sort(items, function(left, right)
        local left_priority = left.opts.priority or 0
        local right_priority = right.opts.priority or 0
        if left_priority ~= right_priority then
            return left_priority > right_priority
        end
        return left.contribution.sequence < right.contribution.sequence
    end)
end

function CompositionAssembler:_append_value(spec, entries)
    local items = {}
    local identities = {}
    local defaults = spec.default_value
    if defaults ~= nil and not widget_array(defaults) then
        self:_warn(spec.id, 'append SlotSpec.default_value must be a Widget array')
    elseif defaults ~= nil then
        for index, widget in ipairs(defaults) do
            if std.isinstance(widget, Widget) then
                local identity = 'default:' .. tostring(index)
                items[#items + 1] = { widget = widget, identity = identity, opts = {} }
                identities[identity] = true
            else
                self:_warn(spec.id, 'append SlotSpec.default_value contains a non-Widget')
            end
        end
    end

    local pending = {}
    for _, entry in ipairs(entries) do
        local item = {
            widget = entry.widget,
            opts = entry.opts,
            contribution = entry.contribution,
        }
        local identity
        if spec.identity ~= nil then
            local ok, result = pcall(spec.identity, entry.opts, entry.contribution)
            if ok then
                identity = result
            end
        end
        identity = identity or entry.opts.name
            or (entry.contribution.scope_id .. ':' .. tostring(entry.contribution.scope_sequence))
        if type(identity) ~= 'string' or identity == '' then
            self:_warn(spec.id, 'append contribution has no usable identity', entry.contribution)
        elseif identities[identity] then
            self:_warn(spec.id, string.format("duplicate append identity '%s'", identity), entry.contribution)
        else
            item.identity = identity
            identities[identity] = true
            pending[#pending + 1] = item
        end
    end
    sort_by_priority(pending)

    local known = {}
    for identity in pairs(identities) do
        known[identity] = true
    end
    local by_identity = {}
    for index, item in ipairs(items) do
        by_identity[item.identity] = index
    end

    local function insert_item(item, index)
        table.insert(items, index, item)
        for position = index, #items do
            by_identity[items[position].identity] = position
        end
    end

    local unresolved = pending
    while #unresolved > 0 do
        local next_round = {}
        local progressed = false
        for _, item in ipairs(unresolved) do
            local position = item.opts.pos
            if position == nil then
                position = 'last'
            end
            if position == 'first' then
                insert_item(item, 1)
                progressed = true
            elseif position == 'last' then
                insert_item(item, #items + 1)
                progressed = true
            elseif type(position) == 'table'
                and (position.before ~= nil or position.after ~= nil) then
                local target = position.before or position.after
                if not known[target] then
                    self:_warn(spec.id, string.format(
                        "append position target '%s' is unresolved", tostring(target)), item.contribution)
                    progressed = true
                elseif by_identity[target] == nil then
                    next_round[#next_round + 1] = item
                elseif position.before ~= nil then
                    insert_item(item, by_identity[target])
                    progressed = true
                else
                    insert_item(item, by_identity[target] + 1)
                    progressed = true
                end
            else
                self:_warn(spec.id, 'append pos must be first, last, before or after', item.contribution)
                progressed = true
            end
        end
        if #next_round > 0 and not progressed then
            for _, item in ipairs(next_round) do
                self:_warn(spec.id, 'append relative positions form a cycle', item.contribution)
            end
            break
        end
        unresolved = next_round
    end

    if spec.append_limit ~= nil and #items > spec.append_limit then
        for index = spec.append_limit + 1, #items do
            self:_warn(spec.id, 'append contribution exceeds SlotSpec.append_limit',
                items[index].contribution)
        end
        while #items > spec.append_limit do
            table.remove(items)
        end
    end

    local value = {}
    for _, item in ipairs(items) do
        value[#value + 1] = item.widget
    end
    return value
end

function CompositionAssembler:_resolve(spec, default_value)
    local matching = self:_matching(spec)
    local entries = {}
    for _, contribution in ipairs(matching) do
        local entry = self:_normalize(spec, contribution)
        if entry ~= nil then
            entries[#entries + 1] = entry
        end
    end

    ---@type { widget: Widget, opts: table<string, any>, operation: SlotOperation, contribution: Contribution }[]
    local replacements = {}
    ---@type { widget: Widget, opts: table<string, any>, operation: SlotOperation, contribution: Contribution }[]
    local sets = {}
    ---@type { widget: Widget, opts: table<string, any>, operation: SlotOperation, contribution: Contribution }[]
    local appends = {}
    for _, entry in ipairs(entries) do
        if entry.operation == 'replace' then
            replacements[#replacements + 1] = entry
        elseif entry.operation == 'set' then
            sets[#sets + 1] = entry
        else
            appends[#appends + 1] = entry
        end
    end

    local value = default_value
    local selected_opts = spec.default_opts
    if #replacements > 0 then
        local selected = replacements[#replacements]
        if selected == nil then
            return spec:build(value, selected_opts)
        end
        value = selected.widget
        selected_opts = selected.opts
        for _, entry in ipairs(sets) do
            self:_warn(spec.id, 'set contribution ignored because replace won', entry.contribution)
        end
        for _, entry in ipairs(appends) do
            self:_warn(spec.id, 'append contribution ignored because replace won', entry.contribution)
        end
    elseif #sets > 0 then
        value = sets[1].widget
        selected_opts = sets[1].opts
        for index = 2, #sets do
            self:_warn(spec.id, 'later set contribution ignored; the first valid set wins',
                sets[index].contribution)
        end
        for _, entry in ipairs(appends) do
            self:_warn(spec.id, 'append contribution ignored because set won', entry.contribution)
        end
    elseif #appends > 0 or spec.default_op == 'append' then
        value = self:_append_value(spec, appends)
        selected_opts = spec.default_opts
    end
    return spec:build(value, selected_opts)
end

function CompositionAssembler:_assemble_widget(widget)
    if widget == nil then
        return nil
    end
    if std.isinstance(widget, SlotWrap) then
        return self:_assemble_widget(self:_resolve(widget.spec, widget.default_value))
    end
    if not std.isinstance(widget, Widget) then
        raise(std.TypeError('CompositionAssembler encountered a non-Widget child'))
    end

    local children = widget:child_widgets()
    if #children == 0 then
        return widget_copy(widget)
    end
    local replacements = {}
    for _, child in ipairs(children) do
        replacements[child] = self:_assemble_widget(child)
    end
    local clone = widget_copy(widget)
    local target = rawget(clone --[[@as table]], '__dict') or {}
    for key, value in pairs(target) do
        target[key] = copy_child_value(value, replacements)
    end
    return clone
end

---@param root Widget
---@return Widget root
---@return table[] diagnostics
function CompositionAssembler:assemble(root)
    if not std.isinstance(root, Widget) then
        raise(std.TypeError('CompositionAssembler.root must be a Widget'))
    end
    self.diagnostics = {}
    self._used = {}
    local result = self:_assemble_widget(root)
    for _, contribution in ipairs(self.contributions) do
        if not self._used[contribution] then
            self:_warn(contribution.slot_id, 'no matching SlotSpec in the assembled tree', contribution)
        end
    end
    return result, self.diagnostics
end

M.SlotSpec = SlotSpec
M.SlotWrap = SlotWrap
M.Contribution = Contribution
M.ContributionRegistry = ContributionRegistry
M.CompositionAssembler = CompositionAssembler

return M
