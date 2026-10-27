-- Bare-bones assertion/reporting helpers (no external dependencies).
--
-- Same shape as elxlib's `test/asyncio/framework.lua` so the two suites read
-- the same way.

local F = {}

local n_pass, n_fail = 0, 0
local failures = {}
local suite = '?'
local current_file = '?'
local current_test
local verbose = false

function F.set_verbose(value)
    verbose = value == true
end

function F.file(name)
    current_file = name
    suite = '?'
    if verbose then
        print('\n-- ' .. name .. ' --')
    end
end

local function fmt(v)
    if type(v) == 'string' then
        v = v:gsub('\n', '\\n')
        if #v > 160 then v = v:sub(1, 157) .. '...' end
        return string.format('%q', v)
    end
    return tostring(v)
end

local function record(ok, msg)
    if ok then
        n_pass = n_pass + 1
    else
        n_fail = n_fail + 1
        local location = current_file .. ' / ' .. suite
        if current_test then
            location = location .. ' / ' .. current_test
        end
        local failure = location .. ': ' .. msg
        failures[#failures + 1] = failure
        print('    FAIL  ' .. failure)
    end
    return ok
end

---@param name string
function F.section(name)
    suite = name
    if verbose then
        print('\n== ' .. name .. ' ==')
    end
end

--- Run one test body. A raised error fails the test; assertions inside the
--- body report themselves.
---@param name string
---@param fn fun()
function F.test(name, fn)
    local before = n_fail
    current_test = name
    local ok, err = pcall(fn)
    if not ok then
        record(false, name .. ' -> raised ' .. tostring(err):gsub('\n', ' | '))
    elseif verbose and n_fail == before then
        print('    ok    ' .. name)
    end
    current_test = nil
end

--- Record a failure from outside a test body (e.g. a crashed test file).
---@param msg string
function F.fail(msg)
    record(false, msg)
end

---@param cond any
---@param msg string
function F.ok(cond, msg)
    return record(not not cond, msg)
end

---@param got any
---@param want any
---@param msg string
function F.eq(got, want, msg)
    return record(got == want, string.format('%s (got %s, want %s)', msg, fmt(got), fmt(want)))
end

---@param str any
---@param needle string
---@param msg string
function F.contains(str, needle, msg)
    str = tostring(str)
    return record(str:find(needle, 1, true) ~= nil,
        string.format('%s (%s does not contain %s)', msg, fmt(str), fmt(needle)))
end

---@param got number
---@param want number
---@param msg string
---@param eps number?
function F.close(got, want, msg, eps)
    eps = eps or 1e-9
    return record(math.abs(got - want) <= eps,
        string.format('%s (got %s, want %s +/- %s)', msg, fmt(got), fmt(want), fmt(eps)))
end

--- Assert that `fn` raises and the message contains `name`.
---@param fn fun()
---@param name string
---@param msg string
function F.raises(fn, name, msg)
    local ok, err = pcall(fn)
    if ok then
        return record(false, string.format('%s (expected %s, nothing raised)', msg, name))
    end
    return record(tostring(err):find(name, 1, true) ~= nil,
        string.format('%s (expected %s, got %s)', msg, name, fmt(err)))
end

---@return integer failed, integer passed, string[]
function F.results()
    return n_fail, n_pass, failures
end

---@return boolean all_good
function F.summary()
    print('\n' .. string.rep('-', 60))
    if n_fail == 0 then
        print(string.format('ALL GOOD: %d checks passed', n_pass))
    else
        print(string.format('FAILED: %d failure(s), %d check(s) passed', n_fail, n_pass))
        for _, f in ipairs(failures) do
            print('  - ' .. f)
        end
    end
    return n_fail == 0
end

return F
