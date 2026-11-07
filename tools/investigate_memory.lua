-- Bounded reachability probe on bare LuaJIT, without mp or a logging stub.
local support_mod = require 'test.support'
support_mod.bootstrap('test')
if arg[2] then
    package.preload['widget.player_context'] = assert(loadfile(arg[2]))
end
local player_mod = require 'widget.player_context'
local std = require 'elxlibs.std'
local json_mod = require 'elxlibs.json'
local scenes_mod = require 'tools.benchmark_scenes'
local binding_mod = require 'widget.widgets_binding'
local constraints_mod = require 'layout.constraints'
local text_mod = require 'text.text_layout'
local ass_layout_mod = require 'backends.ass_text_layout'
local ass_mod = require 'backends.ass_canvas'
local ffi = require 'ffi'
local process_memory
if ffi.os == 'Windows' then
    ffi.cdef [[
        typedef struct {
            uint32_t cb, PageFaultCount;
            size_t PeakWorkingSetSize, WorkingSetSize, QuotaPeakPagedPoolUsage,
                QuotaPagedPoolUsage, QuotaPeakNonPagedPoolUsage, QuotaNonPagedPoolUsage,
                PagefileUsage, PeakPagefileUsage, PrivateUsage;
        } MemoryProbeCounters;
        void *GetCurrentProcess(void);
        int GetProcessMemoryInfo(void *, MemoryProbeCounters *, uint32_t);
    ]]
    local kernel = ffi.load('kernel32')
    local psapi = ffi.load('psapi')
    local counters = ffi.new('MemoryProbeCounters[1]') --[[@as any]]
    counters[0].cb = ffi.sizeof(counters[0])
    process_memory = function()
        assert(psapi.GetProcessMemoryInfo(kernel.GetCurrentProcess(), counters, counters[0].cb) ~= 0)
        return assert(tonumber(counters[0].PrivateUsage)), assert(tonumber(counters[0].WorkingSetSize))
    end
end

---@class MemoryProbeObject : std.object
---@overload fun(): self
local Class = std.class.new('MemoryProbeObject')

---@class MemoryProbeDynamic : std.object
---@overload fun(): self

local function collect()
    collectgarbage('collect')
    collectgarbage('collect')
    return collectgarbage('count')
end

local function count(refs)
    local total = 0
    for _ in pairs(refs) do
        total = total + 1
    end
    return total
end

local function run(name, create, batch_size)
    local refs = setmetatable({}, { __mode = 'v' })
    local baseline = collect()
    local samples = {}
    for batch = 1, 5 do
        for index = 1, batch_size do
            create((batch - 1) * batch_size + index, refs)
        end
        samples[batch] = { heap_kib = collect(), survivors = count(refs) }
        if process_memory then
            local private, working = process_memory()
            samples[batch].private_bytes = private
            samples[batch].working_set_bytes = working
        end
    end
    return { name = name, baseline_kib = baseline, samples = samples, batch_size = batch_size }
end

local report = { schema_version = 1, runtime = jit.version, os = ffi.os, arch = ffi.arch,
    legacy_player_context = arg[2] ~= nil, cases = {} }
local function case(name, create, batch_size)
    report.cases[#report.cases + 1] = run(name, create, batch_size or 1000)
end

case('snapshot_raw', function(index, refs)
    refs[index] = player_mod.PlayerSnapshot({ time_pos = index })
end)
case('snapshot_readonly', function(index, refs)
    refs[index] = player_mod.PlayerSnapshot({ time_pos = index }):readonly()
end)
case('snapshot_nested', function(index, refs)
    local tracks = assert(player_mod.PlayerSnapshot({ tracks = { { id = index } } }):get('tracks'))
    refs[index] = tracks[1]
end)
case('class_instance', function(index, refs)
    refs[index] = Class()
end)
case('dynamic_class', function(index, refs)
    refs[index] = std.class.new('MemoryProbeDynamic')
end)
local store = player_mod.PlayerStore({ time_pos = 0 })
case('live_store_replace', function(index, refs)
    refs[index] = store:get()
    store:replace({ time_pos = index })
end)

text_mod.set_default(ass_layout_mod.AssTextLayout())
local binding = binding_mod.WidgetsBinding.ensure_initialized()
local tree = binding:attach(scenes_mod.build('player', 0))
tree.render_owner:set_viewport(constraints_mod.Constraints.tight(1280, 720))
local canvas = ass_mod.AssCanvas()
case('live_player_reconcile', function(index, refs)
    refs[index] = assert(tree.root_element).widget
    tree:set_root_widget(scenes_mod.build('player', index))
    tree.render_owner:layout()
    canvas:reset()
    tree.render_owner:mark_needs_paint()
    tree.render_owner:paint(canvas)
end, 100)
tree:dispose()
case('player_mount_dispose', function(index, refs)
    local mounted = binding:attach(scenes_mod.build('player', index))
    mounted.render_owner:set_viewport(constraints_mod.Constraints.tight(1280, 720))
    mounted.render_owner:layout()
    refs[index * 3] = mounted
    refs[index * 3 + 1] = mounted.root_element
    refs[index * 3 + 2] = mounted.render_owner.root
    mounted:dispose()
end, 100)

local file = assert(io.open(assert(arg[1], 'output JSON path required'), 'w'))
file:write(json_mod.dumps(report), '\n')
file:close()
print(json_mod.dumps(report))
