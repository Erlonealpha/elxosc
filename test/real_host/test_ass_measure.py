"""Reusable measurement service, real libass bounds and repeat stability."""
import importlib.util
import json
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('real_ass_measure_tool', ROOT / 'tools' / 'ass_measure.py')
measure_tool = importlib.util.module_from_spec(spec)
spec.loader.exec_module(measure_tool)


@pytest.mark.real_host
def test_framework_measurement_samples_are_stable(real_host_factory):
    script = Path(__file__).with_name('ass_measure.lua')
    with real_host_factory(f'--script={script}', '--force-window=yes', '--geometry=640x360',
            f'--osd-fonts-dir={ROOT / "fonts"}', '--msg-level=osd/libass=debug') as (client, _, process, log):
        report = measure_tool.measure(client, process, log)
        assert report['status'] == 'ok', report
        assert len(report['samples']) == 6
        assert report['lifecycle'] == {'instances': 1, 'removed': 1}
        for sample in report['samples']:
            assert sample['stable']
            assert len(sample['payload_sha256']) == 64
            assert len(sample['results']) == 3
            assert sample['request']['logical']['operations']
            assert all(result['status'] == 'ok' for result in sample['results'])
        samples = {sample['request']['name']: sample for sample in report['samples']}
        clip = samples['clipped-text']['results'][0]['bounds']
        assert 49 <= clip['left'] < clip['right'] <= 131
        assert 49 <= clip['top'] < clip['bottom'] <= 81
        icon = samples['icon-play']
        assert icon['request']['logical']['size'] == {'width': 24, 'height': 24}
        assert icon['results'][0]['bounds']['width'] < 24
        assert any('MaterialSymbolsRounded-Regular' in line
                   for line in report['environment']['font_selection']), report['environment']
        assert samples['composed-row']['request']['logical']['event_count'] == 2


@pytest.mark.real_host
def test_json_input_empty_clip_and_resolution_coordinates(real_host_factory, tmp_path):
    script = Path(__file__).with_name('ass_measure.lua')
    data = '{\\an7\\pos(0,0)\\bord0\\shad0\\p1}m 40 60 l 140 60 l 140 100 l 40 100'
    samples = [
        {'name': 'rect', 'data': data, 'res_x': 640, 'res_y': 360},
        {'name': 'higher-res', 'data': data, 'res_x': 1280, 'res_y': 720},
        {'name': 'clip', 'data': data.replace('\\p1', '\\clip(60,70,100,90)\\p1'), 'res_x': 640, 'res_y': 360},
        {'name': 'empty', 'data': '', 'res_x': 640, 'res_y': 360},
        {'name': 'after-empty', 'data': data, 'res_x': 640, 'res_y': 360},
    ]
    source = tmp_path / 'requests.json'
    source.write_text(json.dumps({'schema_version': 1, 'scene': 'rects', 'scene_version': 1,
                                  'samples': samples}), encoding='utf-8')
    with real_host_factory(f'--script={script}', '--force-window=yes', '--geometry=640x360') as (client, _, process, log):
        report = measure_tool.measure(client, process, log, source)
        assert report['status'] == 'ok', [(s['request']['name'], s['results']) for s in report['samples']]
        assert report['lifecycle'] == {'instances': 2, 'removed': 2}
        for sample in report['samples']:
            assert sample['stable']
        for sample in report['samples'][:2]:
            bounds = sample['results'][0]['bounds']
            # libass reports rendered image rectangles including tile padding;
            # this checks request-space coordinates, not exact path ink bounds.
            assert bounds['left'] == pytest.approx(40, abs=1)
            assert bounds['top'] == pytest.approx(60, abs=1)
            assert 139 <= bounds['right'] <= 156
            assert 99 <= bounds['bottom'] <= 116
        clip = report['samples'][2]['results'][0]['bounds']
        assert [clip[name] for name in ('left', 'top', 'right', 'bottom')] == pytest.approx((60,70,100,90), abs=1)
        assert all(result['status'] == 'empty' for result in report['samples'][3]['results'])
        assert report['samples'][4]['results'][0]['bounds'] == report['samples'][0]['results'][0]['bounds']
        second = measure_tool.measure(client, process, log, source, repeats=1)
        assert second['status'] == 'ok'


@pytest.mark.real_host
def test_measure_benchmark_compares_real_bounds_for_all_strategies(real_host_factory, tmp_path):
    import subprocess
    legacy = subprocess.run(['git', 'show', '46bc4a2:host/ass_measure.lua'], cwd=ROOT,
                            capture_output=True, check=True).stdout
    source = tmp_path / 'legacy.lua'
    source.write_bytes(legacy)
    script = Path(__file__).with_name('ass_measure_benchmark.lua')
    with real_host_factory(f'--script={script}', '--force-window=yes', '--geometry=640x360',
            f'--osd-fonts-dir={ROOT / "fonts"}') as (client, _, process, log):
        measure_tool.wait_property(client, process, log, 'user-data/elxosc-ass-benchmark-ready', 10)
        measure_tool.wait_viewport(client, process, 10)
        client.command('script-message', 'elxosc-ass-benchmark', str(source), '2', '1', '1')
        raw = measure_tool.wait_property(client, process, log, 'user-data/elxosc-ass-benchmark-report', 30)
        report = json.loads(raw)
        assert report['status'] == 'ok', report
        assert len(report['scenarios']) == 14
        for scene in report['scenarios']:
            assert scene['output_equivalent']
            assert set(scene['variants']) == {'legacy', 'overlay_update', 'native_reuse'}
            assert scene['variants']['legacy']['rounds'][0]['timed_native_calls'] == 4
            assert scene['variants']['native_reuse']['rounds'][0]['timed_native_calls'] == 2
