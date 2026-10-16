-- Real-host fixture for the phase 6.6 PlayerShell contract.

local mp = require 'mp'

local scripts = mp.command_native({ 'expand-path', '~~/scripts' })
package.path = package.path .. ';' .. scripts .. '/?.lua;' .. scripts .. '/?/init.lua'
    .. ';' .. scripts .. '/elxosc/?.lua;' .. scripts .. '/elxosc/?/init.lua'
package.loaded.elxlib = assert(loadfile(scripts .. '/elxlib/init.lua'))('elxlib')

local basic_widgets = require 'widget.widgets.basic'
local player = require 'player'
local player_context = require 'widget.player_context'
local overlay_host = require 'host.overlay_host'

local Button = basic_widgets.OutlinedButton
local Text = basic_widgets.Text
local PlayerScaffold = player.PlayerScaffold
local PlayerShell = player.PlayerShell
local ShellVisibilityController = player.ShellVisibilityController
local PlayerStore = player_context.PlayerStore
local OverlayHost = overlay_host.OverlayHost

local store = PlayerStore({ controls_visibility = 'auto' })
local controller = ShellVisibilityController()
local shell = PlayerShell({
    scaffold = PlayerScaffold({ middle_child = Text('shell-body') }),
    controller = controller,
    title_bar = Button({ label = 'shell-control', on_click = function() end }),
})

local host = OverlayHost({
    player_store = store,
    on_pointer_move = function() controller:pointer_move() end,
    on_pointer_leave = function() controller:pointer_leave() end,
})
host:create('main', shell, {
    z_policy = 'main',
    input_policy = 'interactive',
})

local function publish_mode(mode)
    store:replace(store:get():copy({ controls_visibility = mode }))
    mp.set_property('user-data/elxosc-shell-mode', mode)
end

mp.set_property('user-data/elxosc-shell-mode', 'auto')
mp.register_script_message('elxosc-shell-mode', function(mode)
    publish_mode(mode)
end)

mp.register_script_message('elxosc-shell-pointer', function(event)
    if event == 'move' then
        controller:pointer_move()
    elseif event == 'leave' then
        controller:pointer_leave()
    end
    mp.set_property('user-data/elxosc-shell-pointer', event or '')
end)
