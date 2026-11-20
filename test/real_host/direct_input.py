"""Serialized coordinates/events into a staged production MpInput, without desktop input."""
import json
import time


class DirectInput:
    def __init__(self, process, client):
        self.process, self.client = process, client
        self.sequence = 0
        self.x = self.y = 0
        self.last_result = None
        deadline = time.monotonic() + 5
        while True:
            if process.poll() is not None:
                raise RuntimeError('host exited before direct input became ready')
            try:
                if client.command('get_property', 'user-data/elxosc-test-input-ready') == 'yes':
                    break
            except AssertionError:
                pass
            if time.monotonic() >= deadline:
                raise TimeoutError('direct input bridge did not become ready')
            time.sleep(.02)

    def send(self, event, x=None, y=None, button=''):
        if x is not None:
            self.x, self.y = x, y
        self.sequence += 1
        self.client.command('script-message', 'elxosc-test-input', str(self.sequence), event,
                            str(self.x), str(self.y), button)
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            if self.process.poll() is not None:
                raise RuntimeError('host exited during direct input')
            try:
                raw = self.client.command('get_property', 'user-data/elxosc-test-input-result')
            except AssertionError:
                raw = None  # IPC may observe the event before its Lua callback finishes.
            if raw:
                report = json.loads(raw)
                if report['sequence'] == str(self.sequence):
                    if not report['ok']:
                        raise RuntimeError(report['error'])
                    self.last_result = report['result']
                    return self.last_result
            time.sleep(.01)
        raise TimeoutError('direct input event was not acknowledged')

    def move(self, x, y):
        stamp = time.perf_counter()
        self.send('move', x, y)
        return stamp

    def down(self, button='left'):
        return self.send('down', button=button)

    def up(self, button='left'):
        return self.send('up', button=button)

    def click(self, x, y):
        self.move(x, y)
        self.down()
        self.up()

    def __enter__(self):
        return self

    def __exit__(self, *_):
        if self.process.poll() is None:
            self.send('leave')
