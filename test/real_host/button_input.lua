-- Test-only entry point, loaded as an mpv script from the isolated config.
-- Keep the real App, widget binding, render tree and Button implementation.
---@diagnostic disable: call-non-callable, undefined-field, need-check-nil
local mp = require 'mp'
mp.set_property('user-data/elxosc-test-loaded', 'yes')
local scripts = mp.command_native({ 'expand-path', '~~/scripts' })
package.path = package.path .. ';' .. scripts .. '/?.lua;' .. scripts .. '/?/init.lua'
    .. ';' .. scripts .. '/elxosc/?.lua;' .. scripts .. '/elxosc/?/init.lua'
-- mpv.net does not provide get_script_directory() for this test-only script;
-- initialize the real library entry point with its expected module name.
package.loaded.elxlib = assert(loadfile(scripts .. '/elxlib/init.lua'))('elxlib')

local geometry = require 'foundation.geometry'
local Constraints = require('layout.constraints').Constraints
local app_mod = require 'host.mpv_app'
local layout = require 'widget.widgets.layout'
local basic = require 'widget.widgets.basic'

local count, dispatched = 0, 0
mp.set_property('user-data/elxosc-test-clicks', '0')
mp.set_property('user-data/elxosc-test-dispatched', '0')

local app = app_mod.start(function()
    return layout.Column({
        main_alignment = 'start', cross_alignment = 'start',
        children = {
            basic.Button({
                child = layout.SizedBox({ width = 80, height = 40 }),
                on_click = function()
                    count = count + 1
                    mp.set_property('user-data/elxosc-test-clicks', tostring(count))
                end,
            }),
        },
    })
end)

-- Headless mpv.net has no OSD dimensions when force-window=no. The real App
-- and RenderOwner are still used; provide the same tight viewport contract a
-- visible host would receive so the test can exercise hit testing.
app.owner:set_viewport(Constraints.tight(640, 360))
app.display.width, app.display.height, app.display.initialized = 640, 360, true

-- Readiness means a live render tree with viewport constraints, not merely
-- successful script-message registration or an IPC reply.
local function mark_ready()
    app:render()
    if app.owner.root and not app.owner:needs_layout() then
        mp.set_property('user-data/elxosc-test-ready', 'yes')
        return
    end
    mp.add_timeout(0.05, mark_ready)
end
mark_ready()

mp.register_script_message('elxosc-test-pointer', function(event, x, y)
    mp.set_property('user-data/elxosc-test-seen', tostring(event))
    if event ~= 'down' and event ~= 'up' then return end
    local px, py = tonumber(x), tonumber(y)
    if not px or not py then return end
    app.owner:dispatch_pointer(event, geometry.Offset(px, py))
    dispatched = dispatched + 1
    mp.set_property('user-data/elxosc-test-dispatched', tostring(dispatched))
end)
