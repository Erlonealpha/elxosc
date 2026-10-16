-- Real-host fixture for the multi-layer OverlayHost contract.

local mp = require 'mp'

local scripts = mp.command_native({ 'expand-path', '~~/scripts' })
package.path = package.path .. ';' .. scripts .. '/?.lua;' .. scripts .. '/?/init.lua'
    .. ';' .. scripts .. '/elxosc/?.lua;' .. scripts .. '/elxosc/?/init.lua'
package.loaded.elxlib = assert(loadfile(scripts .. '/elxlib/init.lua'))('elxlib')

local overlay_host = require 'host.overlay_host'
local basic_widgets = require 'widget.widgets.basic'

local OverlayHost = overlay_host.OverlayHost
local Text = basic_widgets.Text

local host = OverlayHost()
host:create('main', Text('main'), { z_policy = 'main', input_policy = 'passive' })
host:create('extension', Text('extension'), {
    z_policy = 'extension',
    input_policy = 'passive',
})
host:create('popup', Text('popup'), {
    z_policy = 'popup',
    input_policy = 'passive',
})

local function publish_state()
    local visible = {}
    for _, layer in ipairs(host.registry:sorted()) do
        if layer.visible then
            visible[#visible + 1] = layer.id
        end
    end
    mp.set_property('user-data/elxosc-overlay-state', table.concat(visible, ','))
end

publish_state()

mp.register_script_message('elxosc-overlay-hide-popup', function()
    host:hide('popup')
    publish_state()
end)

mp.register_script_message('elxosc-overlay-show-popup', function()
    host:show('popup')
    publish_state()
end)

mp.register_script_message('elxosc-overlay-remove-extension', function()
    host:remove('extension')
    publish_state()
end)
