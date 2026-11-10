"""Native input through both append-only bottom player control slots."""

from pathlib import Path
import time
import wave

import pytest

from test_elxosc import wait_for_property
from window_input import WindowInput


@pytest.mark.real_host
def test_left_and_right_appended_buttons_receive_native_clicks(real_host_factory, tmp_path):
    script = Path(__file__).parents[2] / 'main.lua'
    peer = tmp_path / 'extension_buttons.lua'
    peer.write_text(
        "local mp = require 'mp'\n"
        "local code = [[\n"
        "import('mp')\n"
        "import('player')\n"
        "bind('player.controls.left', PlayerControlButton({ icon = 'toggle_off', "
        "on_click = function() set_prop('user-data/extensions-left', 'first') end }))\n"
        "bind('player.controls.left', PlayerControlButton({ icon = 'toggle_on', "
        "on_click = function() set_prop('user-data/extensions-left', 'second') end }))\n"
        "bind('player.controls.right', PlayerControlButton({ icon = 'toggle_off', "
        "on_click = function() set_prop('user-data/extensions-right', 'first') end }))\n"
        "bind('player.controls.right', PlayerControlButton({ icon = 'toggle_on', "
        "on_click = function() set_prop('user-data/extensions-right', 'second') end }))\n"
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
                           '--geometry=1920x1080') as (client, _, process, log):
        wait_for_property(client, process, log, 'user-data/elxosc-demo-open', 'false')
        client.command('set_property', 'pause', True)
        client.command('loadfile', str(media))
        wait_for_property(client, process, log, 'idle-active', False)
        dimensions = client.command('get_property', 'osd-dimensions')
        width, height = dimensions['w'], dimensions['h']
        with WindowInput(process, client) as pointer:
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
