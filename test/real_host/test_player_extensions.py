"""Direct production input through both append-only player control slots."""

from pathlib import Path
import time
import wave

import pytest

from test_elxosc import wait_for_property
from direct_input import DirectInput


@pytest.mark.real_host
def test_left_and_right_appended_buttons_receive_direct_clicks(real_host_factory, tmp_path):
    script = Path(__file__).parents[2] / 'main.lua'
    peer = tmp_path / 'extension_buttons.lua'
    peer.write_text(
        "local mp = require 'mp'\n"
        "local code = [[\n"
        "local defaults_are_minimal = Text == nil and Button == nil and Color == nil "
        "and Widget == nil and PlayerScope == nil and SlotSpec == nil "
        "and new_widget ~= nil and new_state ~= nil\n"
        "local host = require('mp')\n"
        "local player = require('player')\n"
        "local standard = require('std')\n"
        "local utils_work = type(standard.class.new) == 'function' "
        "and std == nil and rawequal(standard.class, import_as('std').class) "
        "and tostring(math.floor(tonumber('2.8'))) == '2' "
        "and table.concat({ 'a', 'b' }, ',') == 'a,b'\n"
        "local stack = import_as('render.stack')\n"
        "local widgets = import_as('material.slider')\n"
        "local context = import_as('player.context')\n"
        "local base = import_as('widgets.framework')\n"
        "local painting = import_as('painting.canvas')\n"
        "local exports = import_as('export').new()\n"
        "exports.export('peer.controls', { button = player.PlayerControlButton })\n"
        "import('render.stack')\n"
        "host.set_prop('user-data/extensions-modules', "
        "(defaults_are_minimal and utils_work and stack.RenderStack == RenderStack and widgets.Slider ~= nil "
        "and context.PlayerStore == player.PlayerStore and base.Widget ~= nil "
        "and painting.Canvas ~= nil and exports.get('peer.controls').button == player.PlayerControlButton) "
        "and 'true' or 'false')\n"
        "bind('player.controls.left', player.PlayerControlButton({ icon = 'toggle_off', "
        "on_click = function() host.set_prop('user-data/extensions-left', 'first') end }))\n"
        "bind('player.controls.left', player.PlayerControlButton({ icon = 'toggle_on', "
        "on_click = function() host.set_prop('user-data/extensions-left', 'second') end }))\n"
        "bind('player.controls.right', player.PlayerControlButton({ icon = 'toggle_off', "
        "on_click = function() host.set_prop('user-data/extensions-right', 'first') end }))\n"
        "bind('player.controls.right', player.PlayerControlButton({ icon = 'toggle_on', "
        "on_click = function() host.set_prop('user-data/extensions-right', 'second') end }))\n"
        "]]\n"
        "mp.commandv('script-message-to', 'elxosc', 'define_start')\n"
        "mp.commandv('script-message-to', 'elxosc', 'define', 'extension-buttons', code)\n"
        "mp.commandv('script-message-to', 'elxosc', 'define_end')\n",
        encoding='utf-8',
    )
    media = tmp_path / 'extensions.wav'
    with wave.open(str(media), 'wb') as stream:
        stream.setparams((1, 2, 48000, 0, 'NONE', 'not compressed'))
        stream.writeframes(bytes(48000 * 2 * 12))
    with real_host_factory(f'--script={script}', f'--scripts-append={peer}', '--force-window=yes',
                           '--geometry=1920x1080', direct_input=True) as (client, _, process, log):
        wait_for_property(client, process, log, 'user-data/elxosc-demo-open', 'false')
        wait_for_property(client, process, log, 'user-data/extensions-modules', 'true')
        client.command('set_property', 'pause', True)
        client.command('loadfile', str(media))
        wait_for_property(client, process, log, 'idle-active', False)
        dimensions = client.command('get_property', 'osd-dimensions')
        width, height = dimensions['w'], dimensions['h']
        with DirectInput(process, client) as pointer:
            y = int(height - 40 * 1.5)
            # 80px volume slider ends at 235; left controls start at 268.
            for x, property_name, expected in (
                (268 * 1.5, 'user-data/extensions-left', 'first'),
                (313 * 1.5, 'user-data/extensions-left', 'second'),
                (width - 172 * 1.5, 'user-data/extensions-right', 'first'),
                (width - 217 * 1.5, 'user-data/extensions-right', 'second'),
            ):
                pointer.move(int(x), y)
                time.sleep(0.15)
                pointer.click(int(x), y)
                wait_for_property(client, process, log, property_name, expected)
