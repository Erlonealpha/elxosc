"""Sustained native/estimate cache bounds and App ownership; no pointer driver."""
import hashlib
import json
import time
from pathlib import Path

import pytest

from test_ass_text_probe import resize_viewport

ROOT = Path(__file__).resolve().parents[2]


@pytest.mark.real_host
def test_sustained_text_cache_environment_replacement_and_cleanup(real_host_factory):
    script = Path(__file__).with_name('text_cache_endurance.lua')
    with real_host_factory(f'--script={script}', '--force-window=yes', '--geometry=1280x720',
            '--osd-font=Arial') as (client, _, process, log):
        from test_ass_text_probe import measure_tool
        measure_tool.wait_property(client, process, log, 'user-data/elxosc-cache-endurance-ready', 10)
        resize_viewport(client, process, log, 1280, 720)
        client.command('script-message', 'elxosc-cache-endurance', '120', '240')
        deadline = time.monotonic() + 145
        report = None
        while time.monotonic() < deadline:
            assert process.poll() is None, log.read_text(errors='replace')[-3000:]
            value = client.command('get_property', 'user-data/elxosc-cache-endurance-report', timeout=2)
            if value:
                report = json.loads(value)
                break
            time.sleep(.5)
        assert report is not None, log.read_text(errors='replace')[-3000:]
        assert 'error' not in report, report
        assert report['duration'] >= 120
        assert report['work'] >= 20000
        assert len(report['replacements']) == 3
        assert report['old_layouts_retained'] == 0
        assert report['other']['source'] == 'native' and report['other']['isolated']
        assert len(report['ids']) == len(set(report['ids']))
        assert all(report['removals'][str(identifier)] == 1 for identifier in report['ids'])
        stats = [sample['stats'] for sample in report['samples']]
        assert all(item['entries'] <= 512 and item['bytes'] <= 262144 for item in stats)
        assert any(item['entries'] == 512 and item['evictions'] > 0 for item in stats)
        assert any(item['entries'] < 512 and item['bytes'] > 260000 and item['evictions'] > 0 for item in stats)
        report['source'] = {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest()
            for name in ('lib/src/backends/ass_text_layout.lua', 'host/mpv_app.lua',
                         'test/real_host/text_cache_endurance.lua', 'test/real_host/test_text_cache_endurance.py')}
        (ROOT / 'tmp/text-cache-ATL-4.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
