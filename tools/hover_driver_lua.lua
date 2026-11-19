-- Standalone adapter; the shared driver supplies the bounded mp boundary.
require('test.support').bootstrap('test')
local mp = require('mp_stub').install()
local options = {}
if arg[4] then
    local file = assert(io.open(arg[4], 'rb'))
    options = require('elxlibs.json').loads(file:read('*a'))
    file:close()
end
if options.mode == 'table-sites' then
    options.sites = require('tools.hover_profiler').install_sites('.')
end
local driver = require 'tools.hover_driver'
local report = driver.run(mp, assert(arg[1]), assert(tonumber(arg[2])) --[[@as integer]], false, options)
driver.write(assert(arg[3]), report)
print(string.format('%s: %d pointer events, %d frame callbacks, %d actual updates',
    report.trace.name, report.pointer_events, report.counts.callbacks, report.counts.updates))
