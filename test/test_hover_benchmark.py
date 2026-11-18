"""Hover accounting preserves repeated frames and reports the actual driven workload."""
import importlib.util
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('hover_benchmark', ROOT / 'tools/benchmark_real_player_hover.py')
probe = importlib.util.module_from_spec(spec)
spec.loader.exec_module(probe)


def test_native_cost_and_label_accounting_include_repeated_player_frames():
    trace = {'qpc': False, 'events': [
        {'seq': 1, 'time': 1, 'finish': 1.001, 'x': 100, 'y': 50},
        {'seq': 2, 'time': 1.01, 'finish': 1.011, 'x': 101, 'y': 50}],
        'frames': []}
    for seq, label, calls, measurements in [(1, '00:01', 2, [.0001, .0002]),
                                            (1, '00:02', 2, [.0003, .0004]),
                                            (2, '00:02', 0, [])]:
        trace['frames'].append({'input_seq': seq, 'start': 1 + seq * .01, 'finish': 1.003 + seq * .01,
            'label': label, 'stages': {}, 'build_dirty': False, 'layout_needed': False,
            'regions_changed': False, 'native_calls': calls, 'cache_hits': 1,
            'native_seconds': measurements, 'ass_events': 10, 'ass_bytes': 500, 'text_generation': 2})
    motions = [{'sent': .999, 'finished': 1, 'deadline': .999, 'x': 100, 'y': 50},
               {'sent': 1.009, 'finished': 1.01, 'deadline': 1.009, 'x': 101, 'y': 50}]
    summary = probe.summarize(trace, motions, 1)
    assert summary['tooltip_frames'] == 2 and summary['all_tooltip_frames'] == 3
    assert summary['all_native_text_calls'] == 4 and summary['native_measurement']['count'] == 4
    assert summary['unique_labels'] == 2
    assert summary['ass_events'] == [10] and summary['ass_bytes'] == {'min': 500, 'max': 500}
    assert summary['text_generations'] == [2]
    assert summary['coalesced_input_events'] == 0
