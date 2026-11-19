-- Bounded, removable instrumentation for shared-driver measurements.
---@namespace elxosc.tools.hover
local timing = require 'tools.benchmark_support'
local M = {}
local unpack = unpack

local function distribution(values)
    if #values == 0 then
        return { count = 0, mean_ms = 0, p50_ms = 0, p95_ms = 0, p99_ms = 0, max_ms = 0 }
    end
    local result = timing.distribution(values) --[[@as table]]
    result.p99_ms = values[math.ceil(#values * 0.99)] * 1000
    return result
end
M.distribution = distribution

---@param mode string
---@return table
function M.new(mode)
    local profiler = { mode = mode, active = false, stack = {}, nodes = {}, constructors = {},
        sites = {}, restores = {}, samples = {}, states = {}, class_identities = {}, sample_count = 0, dropped_samples = 0,
        max_keys = 2048, keys = 0, frame_id = 0, batch_id = 0 } --[[@as table]]
    local function pack(...)
        return { n = select('#', ...), ... }
    end
    local start = timing.now()
    for _ = 1, 1000 do
        timing.now()
    end
    profiler.clock_probe = { reads = 1000, seconds_per_read = (timing.now() - start) / 1001 }
    function profiler:enter(name)
        if not self.active or self.mode ~= 'phase' then
            return nil
        end
        local parent = self.stack[#self.stack]
        local key = parent and parent.key .. ' > ' .. name or name
        if not self.nodes[key] then
            assert(self.keys < self.max_keys, 'phase key capacity exceeded')
            self.nodes[key] = { name = name, inclusive = {}, exclusive = {}, calls = 0, records = {} }
            self.keys = self.keys + 1
        end
        local scope = { key = key, start = timing.now(), child = 0, frame_id = self.frame_id,
            batch_id = self.batch_id }
        self.stack[#self.stack + 1] = scope
        return scope
    end
    function profiler:leave(scope)
        if not scope then
            return
        end
        local elapsed = timing.now() - scope.start
        assert(self.stack[#self.stack] == scope, 'profiler scopes out of order')
        self.stack[#self.stack] = nil
        local node = self.nodes[scope.key]
        node.calls = node.calls + 1
        assert(node.calls <= 32768, 'phase call capacity exceeded')
        node.inclusive[node.calls] = elapsed
        node.exclusive[node.calls] = math.max(0, elapsed - scope.child)
        node.records[node.calls] = { frame_id = scope.frame_id, batch_id = scope.batch_id,
            inclusive_seconds = elapsed, exclusive_seconds = node.exclusive[node.calls] }
        local parent = self.stack[#self.stack]
        if parent then
            parent.child = parent.child + elapsed
        end
    end
    function profiler:call(name, callback, ...)
        if not self.active or self.mode ~= 'phase' then
            local previous = self.stage
            self.stage = name
            local function restore(...)
                self.stage = previous
                return ...
            end
            return restore(callback(...))
        end
        local scope = self:enter(name)
        local values = pack(pcall(callback, ...))
        self:leave(scope)
        if not values[1] then
            error(values[2], 0)
        end
        return unpack(values, 2, values.n)
    end
    function profiler:wrap(target, slot, name)
        local previous = rawget(target, slot)
        local callback = target[slot]
        assert(type(callback) == 'function', 'missing profile target: ' .. name)
        target[slot] = function(...)
            return self:call(name, callback, ...)
        end
        self.restores[#self.restores + 1] = function()
            target[slot] = previous
        end
    end
    function profiler:start()
        self.active = true
        if self.mode == 'class-count' then
            local object = require('elxlibs.std.class').object
            local original = object.__new --[[@as function]]
            object.__new = function(cls, ...)
                if self.active then
                    local name = cls.__name
                    if self.class_identities[name] and self.class_identities[name] ~= cls then
                        error('constructor class name collision: ' .. name)
                    end
                    self.class_identities[name] = cls
                    local counts = self.constructors[name]
                    if not counts then
                        assert(self.keys < self.max_keys, 'constructor key capacity exceeded')
                        local definition = debug.getinfo(cls.__init, 'S') --[[@as table]]
                        counts = { entries = 0, stages = {}, init_source = definition.source:gsub('\\', '/')
                            :gsub('^@.*[/]elxosc[/]', ''):gsub('^@.*[/]elxlib[/]', 'elxlib/')
                            :gsub('^@', ''):gsub('^%./', ''), init_line = definition.linedefined }
                        self.constructors[name] = counts
                        self.keys = self.keys + 1
                    end
                    counts.entries = counts.entries + 1
                    local stage = self.stage or 'service'
                    counts.stages[stage] = (counts.stages[stage] or 0) + 1
                end
                return original(cls, ...)
            end
            self.restores[#self.restores + 1] = function()
                object.__new = original
            end
        elseif self.mode == 'sample-function' or self.mode == 'sample-line' then
            local ok, api = pcall(require, 'jit.profile')
            self.profile_available = ok
            if ok then
                self.profile_api = api
                local spec = self.mode == 'sample-line' and 'li10' or 'fi10'
                self.sampling_spec = spec
                api.start(spec, function(thread, count, state)
                    if not self.active then
                        return
                    end
                    self.sample_count = self.sample_count + count
                    self.states[state] = (self.states[state] or 0) + count
                    local stack = api.dumpstack(thread, 'pl;', -6):gsub('\\', '/')
                    -- Keep runtime/staging paths out of the exported report.
                    stack = stack:gsub('[^;\n]*[/]elxosc[/]', ''):gsub('[^;\n]*[/]elxlib[/]', 'elxlib/')
                    stack = stack:gsub('%a:/[^;\n]*', '<runtime>')
                    if self.samples[stack] then
                        self.samples[stack] = self.samples[stack] + count
                    elseif self.keys < self.max_keys then
                        self.samples[stack] = count
                        self.keys = self.keys + 1
                    else
                        self.dropped_samples = self.dropped_samples + count
                    end
                end)
            end
        end
    end
    function profiler:stop()
        self.active = false
        if self.profile_api then
            self.profile_api.stop()
            self.profile_api = nil
        end
        for index = #self.restores, 1, -1 do
            self.restores[index]()
        end
        self.restores = {}
        self.unfinished_scopes = #self.stack
        self.stack = {}
    end
    function profiler:report()
        if self.active then
            error('profiler report must be frozen')
        end
        local phases = {}
        for key, node in pairs(self.nodes) do
            phases[key] = { name = node.name, calls = node.calls, inclusive = distribution(node.inclusive),
                exclusive = distribution(node.exclusive), records = node.records }
        end
        return { mode = self.mode, clock = timing.clock, phases = phases, constructors = self.constructors,
            table_sites = self.sites, site_coverage = self.site_coverage, clock_probe = self.clock_probe,
            states = self.states, stacks = self.samples, samples = self.sample_count,
            dropped_samples = self.dropped_samples, max_keys = self.max_keys,
            sampling_spec = self.sampling_spec, profile_available = self.profile_available,
            unfinished_scopes = self.unfinished_scopes,
            coverage = 'phase wrappers include their own clock/pcall/return-table cost; source constructor entries are not physical allocations' }
    end
    return profiler
end

-- Selected source sites run only in fresh adapter processes before the driver imports
-- these modules. Local environments carry the counter; production files are unchanged.
local source_specs = {
    ['player.src.context'] = { path = 'player/src/context.lua', edits = {
        { '    local copy = {}\n', 'snapshot.copy_table', 'creation' },
        { '        copy[copy_key(key)] =', 'snapshot.copy_field', 'field' },
        { '    local fields = {}\n', 'snapshot.export_table', 'creation' },
        { '        fields[name] = copy_value', 'snapshot.export_field', 'field' },
        { '    local active = {}\n', 'store.compact_table', 'creation' },
        { '        if subscription and subscription:is_active() then\n            active[#active + 1]',
            'store.compact_visit', 'visit' },
        { '        if not data_equal(value, right[key], seen) then', 'snapshot.equality_visit', 'visit' },
    } },
    ['src.render.region_snapshot'] = { path = 'lib/src/render/region_snapshot.lua', edits = {
        { '    local copy = {}\n', 'regions.copy_array', 'creation' },
        { '        copy[index] = {', 'regions.copy_record', 'creation' },
    } },
    ['src.render.render_object'] = { path = 'lib/src/render/render_object.lua', edits = {
        { '    out[#out + 1] = { node = self, point = point }', 'pointer.path_record', 'creation' },
        { '    self:_append_pointer_region(out, local_to_root)', 'regions.node_visit', 'visit' },
        { '        local rect = out[index].rect:intersect(clip)', 'regions.ancestor_clip_entry', 'visit' },
        { '    local wants_down = self:wants_pointer', 'regions.claim_visit', 'visit' },
        { 'function RenderObject:mark_needs_layout()\n', 'dirty.layout_mark', 'call' },
        { 'function RenderObject:mark_needs_paint()\n', 'dirty.paint_mark', 'call' },
    } },
    ['src.widgets.element'] = { path = 'lib/src/widgets/element.lua', edits = {
        { 'function StatelessElement:element_children()\n', 'element.stateless_children', 'array-return call' },
        { 'function StatefulElement:element_children()\n', 'element.stateful_children', 'array-return call' },
        { 'function ProxyElement:element_children()\n', 'element.proxy_children', 'array-return call' },
        { 'function MultiChildRenderObjectElement:element_children()\n', 'element.multichild_children', 'existing-array-return call' },
    } },
}

---@param root string
---@return table
function M.install_sites(root)
    local state = { active = false, counts = {}, coverage = {}, originals = {} }
    for name in pairs(source_specs) do
        assert(package.loaded[name] == nil, 'table-site module already loaded: ' .. name)
    end
    for name, spec in pairs(source_specs) do
        assert(package.loaded[name] == nil, 'table-site module already loaded: ' .. name)
        local file = assert(io.open(root .. '/' .. spec.path, 'rb'))
        local source = file:read('*a'):gsub('\r\n', '\n')
        file:close()
        for _, edit in ipairs(spec.edits) do
            local first = assert(source:find(edit[1], 1, true), 'table site marker missing: ' .. edit[2])
            assert(not source:find(edit[1], first + #edit[1], true), 'table site marker not unique: ' .. edit[2])
            local marker = '__hover_site(\'' .. edit[2] .. '\'); '
            if edit[1]:sub(1, 9) == 'function ' then
                local last = first + #edit[1] - 1
                source = source:sub(1, last) .. marker .. source:sub(last + 1)
                if edit[2] == 'dirty.layout_mark' or edit[2] == 'dirty.paint_mark' then
                    local field = edit[2] == 'dirty.layout_mark' and 'needs_layout' or 'needs_paint'
                    source = source:sub(1, last + #marker) .. 'if self.' .. field
                        .. ' then __hover_site(\'' .. edit[2] .. '.repeated\') end; '
                        .. source:sub(last + #marker + 1)
                    state.coverage[edit[2] .. '.repeated'] = { module = name, source = spec.path,
                        category = 'already-dirty call' }
                end
            else
                source = source:sub(1, first - 1) .. marker .. source:sub(first)
            end
            state.coverage[edit[2]] = { module = name, source = spec.path, category = edit[3] }
        end
        local chunk = assert(loadstring(source, '@' .. spec.path))
        setfenv(chunk, setmetatable({ __hover_site = function(site)
            if state.active then
                state.counts[site] = (state.counts[site] or 0) + 1
            end
        end }, { __index = _G }))
        state.originals[name] = { value = package.preload[name] }
        package.preload[name] = chunk
    end
    function state:restore()
        for name, original in pairs(self.originals) do
            package.preload[name] = original.value
        end
    end
    return state
end

return M
