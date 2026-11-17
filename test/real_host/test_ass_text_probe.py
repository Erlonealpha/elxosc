"""Capture real ASS alignment spans before adopting them as layout metrics."""
import importlib.util
import ctypes
import hashlib
import json
import os
import time
from ctypes import wintypes
from pathlib import Path

import pytest
from fontTools.ttLib import TTFont
from window_input import WindowInput

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('text_probe_measure', ROOT / 'tools' / 'ass_measure.py')
measure_tool = importlib.util.module_from_spec(spec)
spec.loader.exec_module(measure_tool)


def requests():
    base = [
        ('latin', 'AV fi Wide'), ('narrow', 'iiii'), ('wide', 'WWWW'),
        ('kerning', 'AV'), ('a', 'A'), ('v', 'V'), ('ligature', 'fi'), ('f', 'f'), ('i', 'i'),
        ('cjk', '中文文本測試'), ('mixed', '时间 01:23 LIVE'),
        ('combining', 'a\u0301'), ('precomposed', 'á'),
        ('emoji', '👩\u200d💻🙂'), ('rtl', 'العربية'),
        ('empty', ''), ('space', ' '), ('spaces', '   '),
        ('leading', ' A'), ('trailing', 'A '), ('both', ' A '),
        ('inner-spaces', 'A   V'), ('nbsp', '\u00a0'), ('nbsp-spaces', '\u00a0\u00a0\u00a0'),
        ('nbsp-leading', '\u00a0A'), ('nbsp-trailing', 'A\u00a0'),
        ('space-fence', '|   |'), ('no-space-fence', '||'), ('single-fence', '|'),
        ('one-space-fence', '| |'), ('two-space-fence', '|  |'),
        ('tab', 'A\tV'), ('ass-literal', r'{tag}\N'),
    ]
    samples = [dict(name=name, text=text, style=dict(font_family='Arial', font_size=24,
                    wrap=False)) for name, text in base]
    for family in ('Arial', 'Courier New', 'Segoe UI'):
        for size in (12, 18, 28, 48):
            for bold, italic in ((False, False), (True, False), (False, True)):
                samples.append(dict(name=f'{family}-{size}-{bold}-{italic}', text='AV fi 01:23',
                    style=dict(font_family=family, font_size=size, bold=bold, italic=italic, wrap=False)))
                if size == 24 or size == 18:
                    for count in (0, 1, 3):
                        samples.append(dict(name=f'blank-{family}-{size}-{bold}-{italic}-{count}', text='',
                            literal_ass=r'\h' * count + '|', style=dict(font_family=family,
                            font_size=size, bold=bold, italic=italic, wrap=False)))
    for spacing in (-30, -2, 0, 2):
        samples.append(dict(name=f'spacing-{spacing}', text='AV fi',
            style=dict(font_family='Arial', font_size=24, letter_spacing=spacing, wrap=False)))
        for name, text in (('spacing-a', 'A'), ('spacing-fence', '| |'),
                           ('spacing-baseline', '||'), ('spacing-marker', '|')):
            samples.append(dict(name=f'{name}-{spacing}', text=text,
                style=dict(font_family='Arial', font_size=24, letter_spacing=spacing, wrap=False)))
    samples.extend([
        dict(name='zero-font', text='Text', style=dict(font_family='Arial', font_size=0)),
        dict(name='icon', text='play_arrow', style=dict(font_family='Material Symbols Rounded', font_size=24)),
        dict(name='default-font', text='AV fi 01:23', style=dict(font_size=18)),
        dict(name='resolved-default-font', text='AV fi 01:23', environment_font=True, style=dict(font_size=18)),
        dict(name='long', text='AV ' * 200, style=dict(font_family='Arial', font_size=24)),
        dict(name='soft-wrap', text='AV ' * 200, soft_wrap=True, style=dict(font_family='Arial', font_size=24)),
        dict(name='clipped', text='AV fi Wide', clip=True, style=dict(font_family='Arial', font_size=24)),
        dict(name='hard-space', text='', literal_ass=r'\h', style=dict(font_family='Arial', font_size=24)),
        dict(name='hard-leading', text='', literal_ass=r'\hA', style=dict(font_family='Arial', font_size=24)),
        dict(name='hard-trailing', text='', literal_ass=r'A\h', style=dict(font_family='Arial', font_size=24)),
        dict(name='hard-fence', text='', literal_ass=r'|\h\h\h|', style=dict(font_family='Arial', font_size=24)),
        dict(name='hard-both', text='', literal_ass=r'\hA\h', style=dict(font_family='Arial', font_size=24)),
        dict(name='space-after-fence', text='', literal_ass=r'|\h', style=dict(font_family='Arial', font_size=24)),
        dict(name='spaces-before-fence', text='', literal_ass=r'\h\h\h|', style=dict(font_family='Arial', font_size=24)),
        dict(name='beyond-edge', text='AV fi Wide', shift=1000, style=dict(font_family='Arial', font_size=24)),
        dict(name='missing-family', text='Fallback 文本', style=dict(font_family='elxosc missing probe font', font_size=24)),
        dict(name='medium-long', text='AV fi Wide ' * 5, style=dict(font_family='Arial', font_size=24)),
        dict(name='effect', text='AV fi Wide', style=dict(font_family='Arial', font_size=24,
            blur_radius=3, outline_width=2)),
    ])
    for scale in (1, 1.5, 2):
        for shift in (-40, 0, 40):
            samples.append(dict(name=f'scale-{scale}-shift-{shift}', text='AV fi Wide', scale=scale,
                shift=shift, style=dict(font_family='Arial', font_size=24, wrap=False)))
    for shift in (0.25, 0.5, 0.75):
        samples.append(dict(name=f'fractional-{shift}', text='AV fi Wide', shift=shift,
            style=dict(font_family='Arial', font_size=24, wrap=False)))
    return samples


def resize_viewport(client, process, log, width, height):
    client.command('set_property', 'fullscreen', False)
    client.command('set_property', 'window-maximized', False)
    if os.name == 'nt':
        with WindowInput(process, client) as window:
            pid = wintypes.DWORD()
            window.user.GetWindowThreadProcessId(window.hwnd, ctypes.byref(pid))
            assert pid.value == window.window_pid
            window.user.ShowWindow.argtypes = [wintypes.HWND, ctypes.c_int]
            window.user.ShowWindow(window.hwnd, 9)
            window.user.SetWindowPos.argtypes = [wintypes.HWND, wintypes.HWND, ctypes.c_int,
                ctypes.c_int, ctypes.c_int, ctypes.c_int, wintypes.UINT]
            assert window.user.SetWindowPos(window.hwnd, None, 0, 0, width, height, 0x16)
    else:
        client.command('set_property', 'geometry', f'{width}x{height}')
    time.sleep(0.15)
    return measure_tool.wait_viewport(client, process, 10)


def span(sample):
    anchors = sample['anchors']
    if any('raw' not in anchors[a] or anchors[a].get('empty') or anchors[a].get('edge')
           for a in ('center_left', 'center', 'center_right')):
        return None
    left, center, right = (anchors[a]['raw'] for a in ('center_left', 'center', 'center_right'))
    scale = sample['request'].get('scale', 1)
    return {name: value / scale for name, value in {
        'left_delta': left['x0'] - right['x0'],
        'right_delta': left['x1'] - right['x1'],
        'left_center': 2 * (left['x0'] - center['x0']),
        'right_center': 2 * (center['x0'] - right['x0']),
        'image_width': left['x1'] - left['x0'],
    }.items()}


def safe_span(sample):
    pair = sample['safe_pair']
    if any(p.get('empty') or p.get('edge') or 'raw' not in p for p in (pair['left'], pair['right'])):
        return None
    distance = pair['right_x'] - pair['left_x']
    scale = sample['request'].get('scale', 1)
    values = [(pair['left']['raw'][key] - pair['right']['raw'][key] + distance) / scale
              for key in ('x0', 'x1')]
    return dict(width=sum(values) / 2, disagreement=abs(values[0] - values[1]))


def check_metrics(report):
    samples = {s['request']['name']: s for s in report['samples']}
    metrics = {name: safe_span(s) for name, s in samples.items()}
    raster_tolerance = 2 * report['res_scale']
    for name, result in metrics.items():
        request = samples[name]['request']
        if result is None or request.get('clip') or name == 'effect' or name == 'spacing--30':
            continue
        tolerance = raster_tolerance / request.get('scale', 1)
        assert result['width'] >= 0 and result['disagreement'] <= tolerance, (name, result)
        centered = span(samples[name])
        if centered is not None:
            assert abs(centered['left_delta'] - result['width']) <= tolerance, (name, centered, result)
            assert abs(centered['left_center'] - result['width']) <= tolerance, (name, centered, result)
    assert metrics['latin']['width'] > metrics['narrow']['width']
    assert metrics['wide']['width'] > metrics['narrow']['width']
    assert abs(metrics['combining']['width'] - metrics['precomposed']['width']) <= raster_tolerance
    assert metrics['long'] is None
    # Clipping may leave a consistent pair: exclude it explicitly instead of relying on disagreement alone.
    assert abs(metrics['clipped']['width'] - metrics['latin']['width']) > raster_tolerance
    assert metrics['space'] is None and metrics['spaces'] is None
    assert metrics['nbsp-leading']['width'] > metrics['leading']['width']
    # Compare exact-count blank prefixes, avoiding multiplication of a quantized single-space result.
    blank_one = metrics['one-space-fence']['width'] - metrics['no-space-fence']['width']
    blank_three = metrics['space-fence']['width'] - metrics['no-space-fence']['width']
    marker_three = metrics['spaces-before-fence']['width'] - metrics['single-fence']['width']
    assert blank_three > blank_one > 0
    assert abs(blank_three - marker_three) <= raster_tolerance
    return metrics


def font_reference(metrics):
    path = Path(os.environ.get('WINDIR', 'C:/Windows')) / 'Fonts' / 'arial.ttf'
    if os.name != 'nt':
        return dict(status='not available on this platform')
    assert path.is_file(), 'Windows reference font unavailable; do not silently substitute it'
    with TTFont(path) as font:
        cmap = font.getBestCmap()
        height = font['hhea'].ascent - font['hhea'].descent
        advances = font['hmtx']
        reference = {}
        for sample, text in (('a', 'A'), ('v', 'V'), ('narrow', 'iiii'), ('wide', 'WWWW'), ('kerning', 'AV')):
            units = sum(advances[cmap[ord(char)]][0] for char in text)
            if text == 'AV':
                units += sum(table.kernTable.get((cmap[65], cmap[86]), 0) for table in font['kern'].kernTables)
            expected = units * 24 / height
            actual = metrics[sample]['width']
            assert abs(actual - expected) <= 1, (sample, actual, expected)
            reference[sample] = dict(expected=expected, measured=actual, error=actual-expected)
    return dict(font='ArialMT', sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                method='hmtx + AV kern; fs24 / hhea height, limited Latin reference', samples=reference)


@pytest.mark.real_host
@pytest.mark.parametrize('geometry', ['640x360', '1280x720', '1600x900'])
def test_capture_alignment_metric_matrix(real_host_factory, tmp_path, geometry):
    bundle = dict(samples=requests())
    source = tmp_path / 'text-requests.json'
    source.write_text(json.dumps(bundle, ensure_ascii=False), encoding='utf-8')
    script = Path(__file__).with_name('ass_text_probe.lua')
    with real_host_factory(f'--script={script}', '--force-window=yes', f'--geometry={geometry}',
            f'--osd-fonts-dir={ROOT / "lib" / "fonts"}', '--msg-level=osd/libass=debug') as (client, _, process, log):
        measure_tool.wait_property(client, process, log, 'user-data/elxosc-text-probe-ready', 10)
        width, height = map(int, geometry.split('x'))
        viewport = resize_viewport(client, process, log, width, height)
        assert abs(viewport['w'] - width) < 150 and abs(viewport['h'] - height) < 150, viewport
        client.command('script-message', 'elxosc-text-probe', str(source))
        report = json.loads(measure_tool.wait_property(client, process, log,
                            'user-data/elxosc-text-probe-report', 30))
        resized = resize_viewport(client, process, log, width + 120, height + 60)
        assert (resized['w'], resized['h']) != (viewport['w'], viewport['h'])
        client.command('set_property', 'user-data/elxosc-text-probe-report', '')
        client.command('script-message', 'elxosc-text-probe', str(source))
        report['resize'] = json.loads(measure_tool.wait_property(client, process, log,
                            'user-data/elxosc-text-probe-report', 30))
        client.command('set_property', 'osd-font', 'Courier New')
        time.sleep(0.25)
        client.command('set_property', 'user-data/elxosc-text-probe-report', '')
        client.command('script-message', 'elxosc-text-probe', str(source))
        font_report = json.loads(measure_tool.wait_property(client, process, log,
                            'user-data/elxosc-text-probe-report', 30))
        report['font_change'] = font_report
        # Fixed virtual resolution differs from the actual raster conditions.
        bundle['res_scale'] = 2
        source.write_text(json.dumps(bundle, ensure_ascii=False), encoding='utf-8')
        client.command('set_property', 'user-data/elxosc-text-probe-report', '')
        client.command('script-message', 'elxosc-text-probe', str(source))
        report['virtual_resolution'] = json.loads(measure_tool.wait_property(client, process, log,
                            'user-data/elxosc-text-probe-report', 30))
        report['font_log'] = [line for line in log.read_text(errors='replace').splitlines()
                              if any(term in line.lower() for term in ('libass', 'fontselect'))]
    report['spans'] = {sample['request']['name']: span(sample) for sample in report['samples']}
    output = ROOT / 'tmp' / f'ass-text-probe-{geometry}.json'
    output.parent.mkdir(exist_ok=True)
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    assert not report.get('error'), report
    assert report['removed'] and not report.get('cleanup_error'), report
    assert report['closed']['kind'] == 'error' and 'disposed' in report['closed']['error']
    assert report['empty_image'] == {}
    assert len(report['samples']) == len(bundle['samples'])
    for sample in report['samples']:
        assert all('raw' in result for result in sample['anchors'].values()), sample
        assert sample['repeat_left']['raw'] == sample['anchors']['center_left']['raw'], sample
    assert report['after_empty'] == report['samples'][0]['anchors']['center_left']['raw']
    for variant in ('resize', 'font_change', 'virtual_resolution'):
        assert not report[variant].get('error') and report[variant]['removed'], report[variant]
    initial_default = next(s for s in report['samples'] if s['request']['name'] == 'default-font')
    changed_default = next(s for s in report['font_change']['samples'] if s['request']['name'] == 'default-font')
    report['default_font_span_changed'] = span(initial_default) != span(changed_default)
    assert report['font_change']['environment']['osd_font'] == 'Courier New'
    original_metrics = check_metrics(report)
    report['font_reference'] = font_reference(original_metrics)
    for variant in ('resize', 'font_change', 'virtual_resolution'):
        check_metrics(report[variant])
    for name in ('latin', 'cjk', 'icon', 'kerning', 'nbsp-leading'):
        resized_sample = next(s for s in report['resize']['samples'] if s['request']['name'] == name)
        assert abs(original_metrics[name]['width'] - safe_span(resized_sample)['width']) <= 2
    initial_resolved = next(s for s in report['samples'] if s['request']['name'] == 'resolved-default-font')
    changed_resolved = next(s for s in report['font_change']['samples'] if s['request']['name'] == 'resolved-default-font')
    assert abs(safe_span(initial_resolved)['width'] - safe_span(changed_resolved)['width']) > 2
    for scale in (1.5, 2):
        scaled = original_metrics[f'scale-{scale}-shift-0']
        assert abs(scaled['width'] - original_metrics['latin']['width']) <= 2
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    for name in ('latin', 'narrow', 'wide', 'cjk', 'mixed', 'icon'):
        assert report['spans'][name] is not None, (name, report['environment'])
