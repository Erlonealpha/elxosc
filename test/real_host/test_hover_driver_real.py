"""Same direct-pointer traces on real ASS renderer and bare LuaJIT, with owned shutdown."""
import importlib.util
import os
import ctypes
from pathlib import Path
from ctypes import wintypes

import pytest
from window_input import _descendants

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('real_hover_driver_tool', ROOT / 'tools/hover_driver.py')
tool = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tool)


@pytest.mark.real_host
def test_shared_hover_traces_and_resource_cleanup(real_host_factory, tmp_path):
    if os.name == 'nt':
        ctypes.windll.user32.GetForegroundWindow.restype = wintypes.HWND
    with real_host_factory(f'--script={ROOT / "test/real_host/hover_driver.lua"}', '--force-window=yes',
            '--geometry=1280x720', '--osd-level=0', f'--osd-fonts-dir={ROOT / "lib/fonts"}', quiet=True) as (client, _, process, log):
        tool.wait_property(client, process, log, 'user-data/elxosc-hover-driver-ready', 20)
        assert client.command('get_property', 'window-minimized') is True
        if os.name == 'nt':
            foreground = ctypes.windll.user32.GetForegroundWindow()
            foreground_pid = wintypes.DWORD()
            ctypes.windll.user32.GetWindowThreadProcessId.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.DWORD)]
            ctypes.windll.user32.GetWindowThreadProcessId(foreground, ctypes.byref(foreground_pid))
            assert foreground_pid.value not in _descendants(process.pid), 'quiet host stole focus'
        client.command('set_property', 'user-data/elxosc-hover-driver-result', '')
        client.command('script-message', 'elxosc-hover-driver', 'playing', '4',
                       str(tmp_path / 'failed-run.json'), '3')
        failure = tool.wait_property(client, process, log, 'user-data/elxosc-hover-driver-result', 20)
        assert 'injected hover driver failure' in failure and 'unreleased' not in failure
        assert not (tmp_path / 'failed-run.json').exists(), 'failed runs must not export success artifacts'
        for scene in tool.SCENES:
            lua = tool.run_lua(scene, 12, tmp_path, 20)
            host = tool.run_host(client, process, log, scene, 12, tmp_path, 20)
            assert tool.compare(lua, host)['equivalent']
            assert host['native_submissions']
    assert process.poll() is not None, 'owned host should exit without manual intervention'


@pytest.mark.real_host
def test_native_record_replay_and_paced_raster_checkpoints(tmp_path):
    spec = importlib.util.spec_from_file_location('real_hover_measure', ROOT / 'tools/hover_measure.py')
    measure = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(measure)
    recorded = measure.native_pair('playing', 16, 0, tmp_path, 20)
    paced = measure.native_pair('paused-ms', 16, 0, tmp_path, 20, paced=True)
    assert recorded['equivalent'] and paced['equivalent']
    assert recorded['requests'] > 0 and paced['requests'] > 0
    assert [point['seq'] for point in paced['paced_checkpoints']] == [1, 8, 16]
    assert paced['visible_frames'] == 'not observed'
