"""Same direct-pointer traces on real ASS renderer and bare LuaJIT, with owned shutdown."""
import importlib.util
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('real_hover_driver_tool', ROOT / 'tools/hover_driver.py')
tool = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tool)


@pytest.mark.real_host
def test_shared_hover_traces_and_resource_cleanup(real_host_factory, tmp_path):
    with real_host_factory(f'--script={ROOT / "test/real_host/hover_driver.lua"}', '--force-window=yes',
            '--geometry=1280x720', '--osd-level=0', f'--osd-fonts-dir={ROOT / "lib/fonts"}') as (client, _, process, log):
        tool.wait_property(client, process, log, 'user-data/elxosc-hover-driver-ready', 20)
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
