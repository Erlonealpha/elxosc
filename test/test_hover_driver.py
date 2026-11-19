"""Behavior comparison and bounded timeout/error handling for the hover CLI."""
import copy
import importlib.util
from pathlib import Path
import subprocess

import pytest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('hover_driver_tool', ROOT / 'tools/hover_driver.py')
tool = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tool)


def test_lua_scene_matrix_preserves_actual_work(tmp_path):
    for scene in tool.SCENES:
        report = tool.validate(tool.run_lua(scene, 12, tmp_path, 15))
        assert report['cleanup'] == {'timers': 0, 'events': 0, 'overlays': 0, 'observers': 0, 'sections': 0}
        assert len(report['frames']) == 12


def test_comparator_reports_first_divergent_frame(tmp_path):
    lua = tool.run_lua('playing', 4, tmp_path, 15)
    host = copy.deepcopy(lua)
    host['native_raster'] = {'x0': 0, 'y0': 0, 'x1': 100, 'y1': 100}
    assert tool.compare(lua, host)['equivalent']
    host['frames'][2]['ass'] += 'changed'
    with pytest.raises(ValueError, match='frame 3'):
        tool.compare(lua, host)


def test_timeout_is_propagated_for_owned_fixture_cleanup(tmp_path):
    class Client:
        def command(self, *args, **kwargs):
            raise TimeoutError('IPC deadline')
    class Process:
        def poll(self):
            return None
    with pytest.raises(TimeoutError, match='IPC deadline'):
        tool.wait_property(Client(), Process(), tmp_path / 'host.log', 'ready', .1)


def test_lua_subprocess_has_a_deadline(monkeypatch, tmp_path):
    def timeout(command, **kwargs):
        assert kwargs['timeout'] == .2
        raise subprocess.TimeoutExpired(command, .2)
    monkeypatch.setattr(tool.subprocess, 'run', timeout)
    with pytest.raises(subprocess.TimeoutExpired):
        tool.run_lua('playing', 4, tmp_path, .2)
