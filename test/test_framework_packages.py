"""Framework collectors run with no player, Define or mpv on the search path."""
import os
from pathlib import Path
import shutil
import subprocess

import pytest


ROOT = Path(__file__).resolve().parents[1]


def test_framework_runs_without_application_packages(tmp_path):
    executable = os.environ.get('ELXOSC_LUAJIT') or shutil.which('luajit')
    if not executable:
        for line in (ROOT / 'project.conf').read_text(encoding='utf-8').splitlines():
            key, separator, value = line.partition('=')
            if separator and key.strip() == 'luajit':
                executable = shutil.which(value.strip())
    if not executable:
        pytest.skip('LuaJIT is unavailable')
    dependency = ROOT.parent / 'elxlib'
    assert (dependency / 'elxlibs' / 'std' / 'init.lua').is_file(), 'elxlib development dependency is missing'
    shutil.copytree(ROOT / 'lib', tmp_path / 'lib')
    result = subprocess.run(
        [executable, str(ROOT / 'test' / 'fixtures' / 'framework_packages.lua'),
         str(tmp_path), str(dependency)],
        cwd=tmp_path, capture_output=True, text=True, timeout=30,
    )
    assert result.returncode == 0, result.stdout + result.stderr
    assert 'framework mount/paint/input/dispose passed' in result.stdout
