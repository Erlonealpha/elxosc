"""Each instrumentation mode runs identical workload, with explicit overhead reporting."""
import importlib.util
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('hover_measure_tool', ROOT / 'tools/hover_measure.py')
tool = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tool)


def test_modes_match_validation_and_count_selected_table_sites(tmp_path):
    validation = tool.driver.run_lua('playing', 32, tmp_path, 20, {'mode': 'validation', 'warmup': 16})
    for mode in tool.MODES:
        report = tool.driver.run_lua('playing', 32, tmp_path, 20, {'mode': mode, 'warmup': 16})
        tool.check_work(validation, report)
        assert report['service']['count'] == 32
        assert report['profiling']['unfinished_scopes'] == 0
        if mode == 'class-count':
            assert report['profiling']['constructors']['Offset']['entries'] > 0
        if mode == 'table-sites':
            assert report['profiling']['table_sites']['snapshot.copy_table'] > 0


def test_probe_workload_divergence_and_noisy_gate_are_explicit(tmp_path):
    validation = tool.driver.run_lua('playing', 16, tmp_path, 20)
    candidate = tool.driver.run_lua('playing', 16, tmp_path, 20, {'mode': 'baseline'})
    candidate['pointer_events'] -= 1
    with pytest.raises(ValueError, match='pointer_events'):
        tool.check_work(validation, candidate)
    report = tool.summarize({'baseline': [{'service': {'mean_ms': n, 'p95_ms': n}} for n in (1, 2, 3)]})
    assert report['pre_candidate_gate']['mean_improvement_fraction'] > .05


def test_unknown_native_replay_request_fails_without_silent_estimate(tmp_path):
    with pytest.raises(tool.driver.subprocess.CalledProcessError):
        tool.driver.run_lua('playing', 16, tmp_path, 20,
                             {'text_mode': 'replay', 'corpus': []})


def test_explicit_data_burst_and_scale_variants_match_measurement(tmp_path):
    for scene, variants in [('data-pressure', {'data_entries': 32}), ('burst', {'burst_moves': 16}),
                            ('environment', {'environment_scale': True}),
                            ('paused-ms', {'style_updates': True})]:
        config = {'warmup': 8, 'trace_options': variants}
        validation = tool.driver.run_lua(scene, 16, tmp_path, 20, config)
        measured = tool.driver.run_lua(scene, 16, tmp_path, 20, dict(config, mode='baseline'))
        tool.check_work(validation, measured)
        assert validation['trace']['variants'] == variants
    assert validation['counts']['dirty_layout'] > 0
