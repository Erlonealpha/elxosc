"""Direct transport ordering and the visible desktop input opt-in boundary."""
import json
from types import SimpleNamespace

import pytest

from direct_input import DirectInput
from window_input import WindowInput


class Client:
    def __init__(self):
        self.events = []
        self.reply = ''
        self.pending = False

    def command(self, *args):
        if args == ('get_property', 'user-data/elxosc-test-input-ready'):
            return 'yes'
        if args[:2] == ('script-message', 'elxosc-test-input'):
            self.events.append(args[2:])
            self.reply = json.dumps({'sequence': args[2], 'ok': True,
                                     'result': {'capture': args[3] == 'down'}})
            self.pending = True
            return None
        if self.pending:
            self.pending = False
            raise AssertionError('property not found')
        return self.reply


def test_click_serializes_move_down_up_and_recovers_pending_reply():
    client = Client()
    process = SimpleNamespace(poll=lambda: None)
    with DirectInput(process, client) as pointer:
        pointer.click(45, 32)
        assert pointer.down()['capture']
        pointer.up()
    assert [e[1] for e in client.events] == ['move', 'down', 'up', 'down', 'up', 'leave']
    assert [e[0] for e in client.events] == ['1', '2', '3', '4', '5', '6']
    assert all(e[2:4] == ('45', '32') for e in client.events)


def test_quiet_process_rejects_desktop_window_input_before_touching_windows():
    with pytest.raises(RuntimeError, match='quiet hosts require DirectInput'):
        WindowInput(SimpleNamespace(_quiet_host=True), None)
