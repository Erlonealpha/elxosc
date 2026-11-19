-- Standalone adapter; the shared driver supplies the bounded mp boundary.
require('test.support').bootstrap('test')
local mp = require('mp_stub').install()
local driver = require 'tools.hover_driver'
local report = driver.run(mp, assert(arg[1]), assert(tonumber(arg[2])) --[[@as integer]], false)
driver.write(assert(arg[3]), report)
print(string.format('%s: %d pointer events, %d frame callbacks, %d actual updates',
    report.trace.name, report.pointer_events, report.counts.callbacks, report.counts.updates))
