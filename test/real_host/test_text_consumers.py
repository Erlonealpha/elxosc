"""Player text hit regions, local toggles and coalesced Tooltip preparation."""
import json
import time
from pathlib import Path

import pytest

from test_ass_text_probe import measure_tool, resize_viewport
from direct_input import DirectInput


ROOT = Path(__file__).resolve().parents[2]


def report(client, process, log, operation='capture', value=''):
    client.command('set_property', 'user-data/elxosc-consumers-report', '')
    client.command('script-message', 'elxosc-consumers', operation, str(value))
    deadline = time.monotonic() + 8
    while time.monotonic() < deadline:
        assert process.poll() is None, log.read_text(errors='replace')[-3000:]
        raw = client.command('get_property', 'user-data/elxosc-consumers-report', timeout=1)
        if raw:
            data = json.loads(raw)
            assert 'error' not in data, data
            return data
        contents = log.read_text(errors='replace')
        assert 'Lua error:' not in contents, contents[-3000:]
        time.sleep(0.05)
    pytest.fail(f'consumer operation {operation} timed out')


def center(rect):
    return int((rect['left'] + rect['right']) / 2), int((rect['top'] + rect['bottom']) / 2)


@pytest.mark.real_host
def test_player_text_regions_and_tooltip_preparation(real_host_factory):
    script = Path(__file__).with_name('text_consumers.lua')
    with real_host_factory(f'--script={script}', '--force-window=yes', '--osd-font=Arial',
            f'--osd-fonts-dir={ROOT / "lib" / "fonts"}', direct_input=True) as (client, _, process, log):
        measure_tool.wait_property(client, process, log, 'user-data/elxosc-consumers-ready', 10)
        resize_viewport(client, process, log, 1280, 720)
        initial = report(client, process, log)
        assert initial['left']['right'] - initial['left']['left'] < 90
        assert initial['right']['right'] - initial['right']['left'] < 90
        desc, bounds = initial['description'], initial['description_bounds']
        assert desc['right'] - desc['left'] < bounds['right'] - bounds['left']
        with DirectInput(process, client) as pointer:
            pointer.click(int(bounds['right'] - 2), int((bounds['top'] + bounds['bottom']) / 2))
            assert not report(client, process, log)['panel_open']
            pointer.click(*center(desc))
            assert report(client, process, log)['panel_open']
            client.command('keypress', 'ESC')
            assert not report(client, process, log)['panel_open']
            pointer.click(*center(initial['left']))
            ms = report(client, process, log)
            assert ms['left_ms']
            assert any(label['text'].endswith('12.250') for label in ms['labels'])
            pointer.click(*center(initial['right']))
            remaining = report(client, process, log)
            assert remaining['remaining']
            stable = report(client, process, log, 'position', 11.111)
            next_state = report(client, process, log, 'position', 12.345)
            assert any(label['text'].endswith('12.345') for label in next_state['labels'])
            assert abs((stable['left']['right'] - stable['left']['left']) -
                       (next_state['left']['right'] - next_state['left']['left'])) <= 2
            pointer.move(0, 0)
        batch = report(client, process, log, 'batch')
        assert batch['dispatch_native'] == 0 and batch['prepared'] == 1, batch
        assert batch['layout_delta'] == 0 and batch['paint_native'] == 0, batch
        assert batch['repeat_native'] == 0 and batch['repeat_prepare'] == 0, batch
        output = ROOT / 'tmp' / 'text-consumers-ATL-2.json'
        output.parent.mkdir(exist_ok=True)
        output.write_text(json.dumps(dict(initial=initial, milliseconds=ms, remaining=remaining,
            stable=stable, next_state=next_state, batch=batch), ensure_ascii=False, indent=2), encoding='utf-8')
