"""Discarded snapshots must be collected by the real host's LuaJIT."""
import time
from pathlib import Path

import pytest
import conftest as host_helpers


@pytest.mark.real_host
def test_snapshot_views_release_backing_data_in_host(real_host_factory, monkeypatch):
    root = Path(__file__).resolve().parents[2]
    original_stage = host_helpers._stage_elxosc

    def stage(source, destination, include_main=True):
        original_stage(source, destination, include_main)
        (destination / 'main.lua').write_bytes(Path(__file__).with_name('player_snapshot_gc.lua').read_bytes())

    monkeypatch.setattr(host_helpers, '_stage_elxosc', stage)
    with real_host_factory(f'--script={root / "main.lua"}') as (client, _, process, log):
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            assert process.poll() is None, log.read_text(errors='replace')
            try:
                result = client.command('get_property', 'user-data/elxosc-snapshot-gc')
                break
            except AssertionError:
                time.sleep(0.05)
        else:
            pytest.fail('snapshot GC fixture did not report: ' + log.read_text(errors='replace'))
        assert result['survivors'] == 0, result
        assert result['retained_id'] == 7, result
        assert result['store_time'] == 201, result
        assert result['runtime'].startswith('LuaJIT'), result
