-- Real-host smoke fixture for the Stage 6 presentation surface adapter.

local mp = require 'mp'

local scripts = mp.command_native({ 'expand-path', '~~/scripts' })
package.path = package.path .. ';' .. scripts .. '/?.lua;' .. scripts .. '/?/init.lua'
    .. ';' .. scripts .. '/elxosc/?.lua;' .. scripts .. '/elxosc/?/init.lua'
package.loaded.elxlib = assert(loadfile(scripts .. '/elxlib/init.lua'))('elxlib')

local presentation = require 'host.presentation_host'
local basic_widgets = require 'widget.widgets.basic'
local constraints = require 'layout.constraints'

local PresentationHost = presentation.PresentationHost
local Text = basic_widgets.Text

local host = PresentationHost()
local default_surface = host:create_surface('default', Text('default'), {
    surface_policy = 'default',
    input_policy = 'passive',
})
local extension_surface = host:create_surface('extension', Text('extension'), {
    surface_policy = 'extension',
    input_policy = 'passive',
})
local popup_surface = host:create_surface('popup', Text('popup'), {
    surface_policy = 'popup',
    input_policy = 'exclusive',
})

-- Headless mpv configurations may report a zero OSD size until a video window
-- exists.  The framework contract is still testable in its logical 1280×720
-- coordinate space, so seed the fixture viewport explicitly.
host.display.width = 1280
host.display.height = 720
host.display.initialized = true
for _, surface in ipairs({ default_surface, extension_surface, popup_surface }) do
    surface.owner:set_viewport(constraints.Constraints.tight(1280, 720))
end

local function overlay_data(surface)
    return surface.presenter.overlay.data or ''
end

local function publish_state()
    mp.set_property('user-data/elxosc-presentation-state', 'default,extension,popup')
    mp.set_property('user-data/elxosc-presentation-ass', string.format('%d,%d,%d',
        #overlay_data(default_surface),
        #overlay_data(extension_surface),
        #overlay_data(popup_surface)))
    mp.set_property('user-data/elxosc-presentation-z', string.format('%d,%d,%d',
        default_surface.presenter.overlay.z,
        extension_surface.presenter.overlay.z,
        popup_surface.presenter.overlay.z))
end

mp.add_timeout(0.1, function()
    host:_update_display()
    host:render()
    publish_state()
end)

mp.register_script_message('elxosc-presentation-hide-popup', function()
    host:hide_surface('popup')
    publish_state()
end)

mp.register_script_message('elxosc-presentation-show-popup', function()
    host:show_surface('popup')
    host:render()
    publish_state()
end)

mp.register_script_message('elxosc-presentation-remove-extension', function()
    host:remove_surface('extension')
    publish_state()
end)
