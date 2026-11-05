"""CLI schema and failure reporting without fabricating host bounds."""
import importlib.util
import json
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('ass_measure_tool', ROOT / 'tools' / 'ass_measure.py')
measure_tool = importlib.util.module_from_spec(spec)
spec.loader.exec_module(measure_tool)


def bundle():
    return {'schema_version': 1, 'scene': 'test', 'scene_version': 1,
            'samples': [{'name': 'empty', 'data': '', 'res_x': 640, 'res_y': 360}]}


@pytest.mark.parametrize('field,value', [('name', ''), ('data', 'a\0b'),
    ('res_x', True), ('res_y', 0), ('res_x', 1.5), ('res_y', 16385)])
def test_rejects_invalid_requests(field, value):
    value_bundle = bundle()
    value_bundle['samples'][0][field] = value
    with pytest.raises(ValueError):
        measure_tool.validate_bundle(value_bundle)


def test_rejects_duplicate_names_and_preserves_empty_payload():
    value = bundle()
    assert measure_tool.validate_bundle(value) is value
    value['samples'].append(value['samples'][0].copy())
    with pytest.raises(ValueError, match='unique'):
        measure_tool.validate_bundle(value)


def test_missing_host_writes_unavailable_report(monkeypatch, tmp_path):
    monkeypatch.setattr(measure_tool.host_helpers, 'find_host', lambda: None)
    output = tmp_path / 'unavailable.json'
    assert measure_tool.main(['--output', str(output)]) == 2
    report = json.loads(output.read_text(encoding='utf-8'))
    assert report['status'] == 'unavailable'
    assert 'samples' not in report


def test_invalid_input_writes_error_before_starting_host(monkeypatch, tmp_path):
    def forbidden():
        pytest.fail('invalid input must not start a host')
    monkeypatch.setattr(measure_tool.host_helpers, 'find_host', forbidden)
    source, output = tmp_path / 'invalid.json', tmp_path / 'error.json'
    source.write_text('{}', encoding='utf-8')
    assert measure_tool.main(['--input', str(source), '--output', str(output)]) == 1
    assert json.loads(output.read_text(encoding='utf-8'))['status'] == 'error'


def test_ipc_timeout_is_propagated_for_owned_process_cleanup(tmp_path):
    class Client:
        def command(self, *args, **kwargs):
            raise TimeoutError('IPC deadline')
    class Process:
        def poll(self):
            return None
    with pytest.raises(TimeoutError, match='IPC deadline'):
        measure_tool.wait_property(Client(), Process(), tmp_path / 'host.log', 'ready', 0.1)


def test_unstable_viewport_times_out():
    class Client:
        def command(self, *args, **kwargs):
            return {'w': 0, 'h': 0}
    class Process:
        def poll(self):
            return None
    with pytest.raises(TimeoutError, match='OSD'):
        measure_tool.wait_viewport(Client(), Process(), 0.05)
