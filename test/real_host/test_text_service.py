"""Native production Text, bounded cache and owned App environment lifecycles."""
import json
import time
from pathlib import Path

import pytest

from test_ass_text_probe import font_reference, measure_tool, resize_viewport


ROOT = Path(__file__).resolve().parents[2]


def command(client, process, log, operation, source=''):
    client.command('set_property', 'user-data/elxosc-text-service-report', '')
    client.command('script-message', 'elxosc-text-service', operation, str(source))
    deadline = time.monotonic() + 8
    while time.monotonic() < deadline:
        assert process.poll() is None, log.read_text(errors='replace')[-3000:]
        value = client.command('get_property', 'user-data/elxosc-text-service-report', timeout=1)
        if value:
            report = json.loads(value)
            break
        contents = log.read_text(errors='replace')
        assert 'Lua error:' not in contents, contents[-3000:]
        time.sleep(0.05)
    else:
        pytest.fail(f'text service operation {operation} timed out: {log.read_text(errors="replace")[-3000:]}')
    assert 'error' not in report, report
    return report


@pytest.mark.real_host
def test_native_text_service_environment_cache_and_cleanup(real_host_factory, tmp_path):
    basic = [('a', 'A'), ('v', 'V'), ('narrow', 'iiii'), ('wide', 'WWWW'), ('kerning', 'AV'),
             ('latin', 'AV fi Wide'), ('cjk', '中文文本測試'), ('combining', 'a\u0301'),
             ('precomposed', 'á'), ('rtl', 'العربية'), ('emoji', '👩\u200d💻🙂'),
             ('literal', r'{tag}\N'), ('leading', ' A'), ('trailing', 'A '),
             ('blank', ' '), ('blanks', '   '), ('nbsp', '\u00a0\u00a0\u00a0'), ('empty', '')]
    samples = [dict(name=name, text=text, style=dict(font_family='Arial', font_size=24, wrap=False))
               for name, text in basic]
    for family in ('Arial', 'Courier New', 'Segoe UI'):
        for size in (12, 18, 28, 48):
            for bold, italic in ((False, False), (True, False), (False, True)):
                samples.append(dict(name=f'{family}-{size}-{bold}-{italic}', text='AV fi 01:23',
                    style=dict(font_family=family, font_size=size, bold=bold, italic=italic, wrap=False)))
    samples.extend([
        dict(name='zero', text='Text', style=dict(font_size=0)),
        dict(name='icon', text='play_arrow', style=dict(font_family='Material Symbols Rounded', font_size=24)),
        dict(name='long', text='AV ' * 200, style=dict(font_family='Arial', font_size=24)),
        dict(name='tab', text='A\tV', style=dict(font_family='Arial', font_size=24)),
    ])
    source = tmp_path / 'text-service-requests.json'
    source.write_text(json.dumps(dict(samples=samples), ensure_ascii=False), encoding='utf-8')
    script = Path(__file__).with_name('text_service.lua')
    with real_host_factory(f'--script={script}', '--force-window=yes', '--geometry=1280x720',
            '--osd-font=Arial', f'--osd-fonts-dir={ROOT / "lib" / "fonts"}') as (client, _, process, log):
        measure_tool.wait_property(client, process, log, 'user-data/elxosc-text-service-ready', 10)
        resize_viewport(client, process, log, 1280, 720)
        matrix = command(client, process, log, 'matrix', source)
        metrics = {sample['name']: sample for sample in matrix['samples']}
        for name, sample in metrics.items():
            expected = 'empty' if name in ('empty', 'zero') else 'estimate' if name in ('long', 'tab') else 'native'
            assert sample['source'] == expected, sample
            assert sample['width'] >= 0 and sample['repeated'] == sample['width'], sample
            assert sample['repeat_calls'] == 0, sample
        matrix['font_reference'] = font_reference(metrics)
        assert abs(metrics['combining']['width'] - metrics['precomposed']['width']) <= 2
        assert metrics['blanks']['width'] > metrics['blank']['width'] > 0
        assert abs(metrics['blanks']['width'] - metrics['nbsp']['width']) <= 2
        assert metrics['leading']['width'] > metrics['a']['width']
        assert metrics['trailing']['width'] > metrics['a']['width']
        assert metrics['long']['reason'] == 'unreliable'
        assert metrics['tab']['reason'] == 'unsupported'
        before = matrix['state']
        assert before['text']['explicit'] == 8 * 18 / 2
        assert before['text']['AV fi 01:23'] != len('AV fi 01:23') * 18 / 2
        assert r'\fnArial' in before['events'] and r'\q2' in before['events']
        assert before['tooltip_width'] > 0 and before['tooltip_generation'] == before['generation']
        client.command('set_property', 'osd-font', 'Courier New')
        time.sleep(0.15)
        changed = command(client, process, log, 'capture')
        assert changed['generation'] > before['generation']
        assert abs(changed['text']['AV fi 01:23'] - before['text']['AV fi 01:23']) > 2
        assert changed['text']['explicit'] == before['text']['explicit']
        assert changed['font'] == 'Courier New'
        assert abs(changed['tooltip_width'] - before['tooltip_width']) > 2
        assert changed['tooltip_generation'] == changed['generation']
        resize_viewport(client, process, log, 960, 540)
        resized = command(client, process, log, 'capture')
        assert resized['generation'] > changed['generation']
        assert (resized['res_x'], resized['res_y']) != (changed['res_x'], changed['res_y'])
        assert abs(resized['text']['AV fi 01:23'] - changed['text']['AV fi 01:23']) <= 2
        pressure = command(client, process, log, 'pressure')
        stats = pressure['state']['stats']
        assert stats['entries'] <= 512 and stats['bytes'] <= 262144 and stats['evictions'] > 0
        fault = command(client, process, log, 'fault')
        assert fault['source'] == 'estimate' and fault['reason'] == 'error' and fault['stopped']
        recovered = command(client, process, log, 'recover')
        assert recovered['stats']['native_calls'] > 0
        assert abs(recovered['text']['AV fi 01:23'] - resized['text']['AV fi 01:23']) <= 2
        closed = command(client, process, log, 'second')
        assert closed['source'] == 'native' and closed['default_unchanged']
        assert len(closed['ids']) == len(set(closed['ids']))
        assert all(closed['removals'][str(identifier)] == 1 for identifier in closed['ids']), closed
    output = ROOT / 'tmp' / 'text-service-ATL-1.json'
    output.parent.mkdir(exist_ok=True)
    output.write_text(json.dumps(dict(matrix=matrix, font_change=changed, resize=resized,
        pressure=pressure, fault=fault, recovered=recovered, closed=closed), ensure_ascii=False, indent=2),
        encoding='utf-8')
