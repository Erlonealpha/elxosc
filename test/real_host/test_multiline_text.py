"""Native whole-line layout, logical row advances, clipping and cost evidence."""
import json
import re
import time
from pathlib import Path

import pytest

from test_ass_text_probe import measure_tool, resize_viewport

ROOT = Path(__file__).resolve().parents[2]
ANCHORS = {
    'top_left': (0, 0), 'top_center': (.5, 0), 'top_right': (1, 0),
    'center_left': (0, .5), 'center': (.5, .5), 'center_right': (1, .5),
    'bottom_left': (0, 1), 'bottom_center': (.5, 1), 'bottom_right': (1, 1),
}


def position(event):
    return tuple(map(float, re.search(r'\\pos\(([-\d.]+),([-\d.]+)\)', event).groups()))


@pytest.mark.real_host
def test_native_multiline_ranges_anchors_overflow_and_cost(real_host_factory, tmp_path):
    samples = []
    for count in (2, 3):
        for anchor in ANCHORS:
            for scale in (1, 1.5, 2):
                samples.append(dict(name=f'rows-{count}-{anchor}-{scale}', text='\n'.join(['Hg'] * count),
                    anchor=anchor, scale=scale, style=dict(font_family='Arial', font_size=24,
                        line_height=2, wrap=False)))
    samples.extend([
        dict(name='empty-row', text='Hg\n\nHg', style=dict(font_family='Arial', font_size=24, line_height=2)),
        dict(name='spaces-tabs', text=' A  V\tX\r\n\nHg\r', style=dict(font_family='Arial', font_size=24)),
        dict(name='cjk', text='中文文本測試', width=52, style=dict(font_family='Arial', font_size=24)),
        dict(name='word', text='hello   world', width=80, style=dict(font_family='Arial', font_size=24)),
        dict(name='ellipsis', text='abcdefghijk', width=60,
            style=dict(font_family='Arial', font_size=24, max_lines=1, overflow='ellipsis')),
        dict(name='combining', text='ááá', width=20, style=dict(font_family='Arial', font_size=24)),
        dict(name='emoji', text='👩‍💻👍🏽🇨🇳', width=20, style=dict(font_family='Segoe UI Emoji', font_size=24)),
        dict(name='narrow', text='WW', width=1,
            style=dict(font_family='Arial', font_size=24, wrap=False, overflow='ellipsis')),
        dict(name='zero', text='A\nB', style=dict(font_family='Arial', font_size=0)),
    ])
    for align in ('left', 'center', 'right'):
        samples.append(dict(name=f'align-{align}', text='Hg\nWider word\nHg',
            style=dict(font_family='Arial', font_size=24, line_height=2, align=align)))
    benchmarks = [dict(name=f'{count}-rows', text='\n'.join(['Hg'] * count),
        style=dict(font_family='Arial', font_size=24, line_height=2)) for count in (1, 2, 3)]
    benchmarks.extend([
        dict(name='latin-wrap', text='AV fi word ' * 40, width=200,
            style=dict(font_family='Arial', font_size=18)),
        dict(name='cjk-wrap', text='中文文本測試' * 30, width=180,
            style=dict(font_family='Arial', font_size=18)),
        dict(name='limited-long-word', text='abcdefgh' * 250, width=160,
            style=dict(font_family='Arial', font_size=18, max_lines=2, overflow='ellipsis')),
    ])
    source = tmp_path / 'multiline-requests.json'
    source.write_text(json.dumps(dict(samples=samples, benchmarks=benchmarks), ensure_ascii=False), encoding='utf-8')
    script = Path(__file__).with_name('multiline_text.lua')
    with real_host_factory(f'--script={script}', '--force-window=yes', '--geometry=1280x720',
            '--osd-font=Arial', '--osd-level=0', f'--osd-fonts-dir={ROOT / "lib" / "fonts"}') as (client, _, process, log):
        measure_tool.wait_property(client, process, log, 'user-data/elxosc-multiline-ready', 10)
        resize_viewport(client, process, log, 1280, 720)
        client.command('script-message', 'elxosc-multiline-text', str(source))
        report = json.loads(measure_tool.wait_property(client, process, log,
            'user-data/elxosc-multiline-report', 45))
        assert 'error' not in report, report
        assert report['cleanup']
        by_name = {sample['name']: sample for sample in report['samples']}
        for request in samples[:54]:
            sample = by_name[request['name']]
            count, scale = len(sample['lines']), request['scale']
            assert len(sample['events']) == count
            assert sample['repeat_native_calls'] == 0
            assert all(metric['source'] == 'native' for metric in sample['metrics'])
            expected_y = 100 + (110 - sample['height'] * ANCHORS[request['anchor']][1] + 24 + 4) * scale
            x, y = position(sample['events'][0])
            assert x == pytest.approx(100 + 203 * scale, abs=.5)
            assert y == pytest.approx(expected_y, abs=.5)
            for previous, current in zip(sample['bounds'], sample['bounds'][1:]):
                assert current['x0'] == previous['x0'] and current['x1'] == previous['x1']
                assert current['y0'] - previous['y0'] == pytest.approx(48 * scale, abs=1)
                assert current['y1'] - previous['y1'] == pytest.approx(48 * scale, abs=1)
            assert all(r'\N' not in event for event in sample['events'])
        for count in (2, 3):
            for scale in (1, 1.5, 2):
                left = by_name[f'rows-{count}-center_left-{scale}']['bounds'][0]
                right = by_name[f'rows-{count}-center_right-{scale}']['bounds'][0]
                width = by_name[f'rows-{count}-center_left-{scale}']['width']
                assert left['x0'] - right['x0'] == pytest.approx(width * scale, abs=2)
                top = by_name[f'rows-{count}-top_left-{scale}']['bounds'][0]
                bottom = by_name[f'rows-{count}-bottom_left-{scale}']['bounds'][0]
                assert top['y0'] - bottom['y0'] == pytest.approx(count * 48 * scale, abs=1)
        blank = by_name['empty-row']
        assert len(blank['events']) == 2
        assert blank['bounds'][1]['y0'] - blank['bounds'][0]['y0'] == pytest.approx(96, abs=1)
        whitespace = by_name['spaces-tabs']
        assert whitespace['lines'] == [' A  V    X', '', 'Hg', '']
        assert whitespace['metrics'][0]['end_byte'] == 8
        for name, source_text in [('cjk', '中文文本測試'), ('word', 'hello   world'),
                                  ('combining', 'ááá'), ('emoji', '👩‍💻👍🏽🇨🇳')]:
            sample = by_name[name]
            assert ''.join(sample['lines']) == source_text
            assert all(metric['source'] == 'native' for metric in sample['metrics']), sample
        assert all(len(line) % 2 == 0 for line in by_name['combining']['lines'])
        assert by_name['emoji']['lines'] == ['👩‍💻', '👍🏽', '🇨🇳']
        ellipsis = by_name['ellipsis']
        assert ellipsis['truncated'] and ellipsis['lines'][0].endswith('…')
        assert ellipsis['width'] <= 60
        assert by_name['narrow']['lines'] == [''] and by_name['narrow']['events'] == []
        assert by_name['zero']['events'] == [] and by_name['zero']['height'] == 0
        aligned = {align: by_name[f'align-{align}'] for align in ('left', 'center', 'right')}
        for index in range(3):
            left, center, right = (aligned[align] for align in ('left', 'center', 'right'))
            row_width = left['metrics'][index]['width']
            assert left['bounds'][index]['x0'] - right['bounds'][index]['x0'] == pytest.approx(row_width, abs=2)
            assert left['bounds'][index]['x0'] - center['bounds'][index]['x0'] == pytest.approx(row_width / 2, abs=2)
            assert row_width < left['width'] if index != 1 else row_width == left['width']
        clip = report['clips']['clip']
        assert all(r'\clip(400,250,430,285)' in event for event in clip['events'])
        assert all(not bounds or (400 <= bounds['x0'] <= bounds['x1'] <= 430
            and 250 <= bounds['y0'] <= bounds['y1'] <= 285) for bounds in clip['bounds'])
        assert all(r'\clip' not in event for event in report['clips']['visible']['events'])
        assert report['clips']['ellipsis']['width'] <= 30
        tooltip = report['tooltip']
        assert len(tooltip['lines']) == 2 and tooltip['truncated'] and tooltip['width'] <= 80
        assert tooltip['lines'][-1].endswith('…')
        assert len(tooltip['events']) == 2
        assert all(metric['source'] == 'native' for metric in tooltip['metrics'])
        for scene in report['benchmarks']:
            assert scene['stats']['entries'] <= 512 and scene['stats']['bytes'] <= 262144
        previews = {page['id']: page for page in report['previews']}
        assert set(previews) == {'layout', 'overflow'}
        for page in previews.values():
            assert (page['res_x'], page['res_y']) == (1280, 720)
            for case in page['cases']:
                assert case['expected'] and len(case['lines']) == case['expected_rows']
        overflow_cases = {case['id']: case for case in previews['overflow']['cases']}
        visible, clipped, shortened = (overflow_cases[key] for key in ('E', 'F', 'G'))
        assert visible['input'] == clipped['input'] == shortened['input']
        assert visible['lines'] == clipped['lines']
        assert not visible['truncated'] and not clipped['truncated']
        assert visible['natural']['width'] > visible['constraint']['width']
        assert clipped['natural']['height'] > clipped['constraint']['height']
        assert shortened['natural']['width'] <= shortened['constraint']['width']
        assert all(line.endswith('…') for line in shortened['lines'])
        output = ROOT / 'tmp' / 'multiline-ATL-3.json'
        black = tmp_path / 'black.ppm'
        black.write_bytes(b'P6\n1280 720\n255\n' + bytes(1280 * 720 * 3))
        client.command('loadfile', str(black))
        time.sleep(.2)
        for page, filename in [('layout', 'multiline-ATL-3.png'), ('overflow', 'multiline-ATL-3-overflow.png')]:
            client.command('script-message', 'elxosc-multiline-preview-page', page)
            value = measure_tool.wait_property(client, process, log, 'user-data/elxosc-multiline-preview-page', 5)
            assert value == page
            time.sleep(.1)
            preview = ROOT / 'tmp' / filename
            client.command('screenshot-to-file', str(preview), 'window')
            assert preview.is_file()
        report['preview_osd'] = client.command('get_property', 'osd-dimensions')
        output.write_text(json.dumps(dict(requests=samples, benchmark_requests=benchmarks,
            report=report), ensure_ascii=False, indent=2), encoding='utf-8')
        client.command('script-message', 'elxosc-multiline-preview-close')
        measure_tool.wait_property(client, process, log, 'user-data/elxosc-multiline-preview-closed', 5)
