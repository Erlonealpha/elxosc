-- Shared timing/statistics for offline and isolated real-host probes. No mp import.
local ffi = require 'ffi'
local M = {}

M.now = os.clock
M.clock = 'os.clock CPU seconds'
if ffi.os == 'Windows' then
    ffi.cdef [[
        int QueryPerformanceCounter(int64_t *value);
        int QueryPerformanceFrequency(int64_t *value);
    ]]
    local frequency = ffi.new('int64_t[1]') --[[@as integer[] ]]
    local counter = ffi.new('int64_t[1]') --[[@as integer[] ]]
    ffi.C.QueryPerformanceFrequency(frequency)
    local divisor = assert(tonumber(frequency[0]))
    M.now = function()
        ffi.C.QueryPerformanceCounter(counter)
        return assert(tonumber(counter[0])) / divisor
    end
    M.clock = 'QueryPerformanceCounter wall seconds'
end

---@class BenchmarkDistribution
---@field count integer
---@field mean_ms number
---@field p50_ms number
---@field p95_ms number
---@field max_ms number

---@param values number[] seconds; sorted in place after measurement
---@return BenchmarkDistribution
function M.distribution(values)
    table.sort(values)
    local total = 0
    for _, value in ipairs(values) do
        total = total + value
    end
    local count = #values
    return {
        count = count, mean_ms = total / count * 1000,
        p50_ms = assert(values[math.ceil(count * 0.5)]) * 1000,
        p95_ms = assert(values[math.ceil(count * 0.95)]) * 1000,
        max_ms = assert(values[count]) * 1000,
    }
end

---@return table
function M.environment()
    return { platform = ffi.os, architecture = ffi.arch, runtime = jit.version,
        jit_enabled = jit.status(), clock = M.clock }
end

return M
