"""Real core runner and comparison boundary; no synthetic performance thresholds."""
import importlib.util
import json
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('framework_benchmark_tool', ROOT / 'tools' / 'benchmark.py')
benchmark_tool = importlib.util.module_from_spec(spec)
spec.loader.exec_module(benchmark_tool)


def test_real_core_runner_is_host_free_and_comparison_checks_output(tmp_path):
    baseline = tmp_path / 'baseline.json'
    current = tmp_path / 'current.json'
    options = ['--iterations', '3', '--warmup', '1', '--rounds', '2']
    assert benchmark_tool.main([*options, '--output', str(baseline)]) == 0
    assert benchmark_tool.main([*options, '--output', str(current), '--baseline', str(baseline)]) == 0
    report = json.loads(current.read_text(encoding='utf-8'))
    assert not report['core']['environment']['mp_loaded']
    assert {scene['name'] for scene in report['core']['scenarios']} == {'small', 'deep', 'wide', 'player'}
    for scene in report['core']['scenarios']:
        assert scene['output_equivalent']
        assert len(scene['output_sha256']) == 64
        assert len(scene['phases']['ass_paint']['rounds']) == 2
    assert len(report['comparison']['rows']) == 4 * (15 + 3)
    assert len(report['core']['animation']) == 4
    assert all(scene['layout_frames'] == 0 and scene['output_equivalent'] for scene in report['core']['animation'])
    old = json.loads(baseline.read_text(encoding='utf-8'))['core']
    old['scenarios'][0]['output_sha256'] = 'changed'
    with pytest.raises(ValueError, match='output differs'):
        benchmark_tool.compare(report['core'], old)


def test_comparison_rejects_different_runtime(tmp_path):
    report = benchmark_tool.core(2, 1, 1, tmp_path)
    baseline = json.loads(json.dumps(report))
    baseline['environment']['runtime'] = 'different runtime'
    with pytest.raises(ValueError, match='environment'):
        benchmark_tool.compare(report, baseline)


def test_invalid_batch_is_rejected_before_execution(monkeypatch, tmp_path):
    def forbidden(*args):
        pytest.fail('invalid input ran benchmark')
    monkeypatch.setattr(benchmark_tool, 'core', forbidden)
    with pytest.raises(SystemExit) as error:
        benchmark_tool.main(['--iterations', '0', '--output', str(tmp_path / 'bad.json')])
    assert error.value.code == 2
