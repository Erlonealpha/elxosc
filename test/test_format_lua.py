"""Exercise formatting scope, read-only checks and write behavior with real luafmt."""

import json
from pathlib import Path
import shutil
import subprocess
import sys

import pytest


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from format_lua import formatter_executable


@pytest.fixture
def project(tmp_path):
    executable = shutil.which(formatter_executable())
    if executable is None:
        pytest.skip('EmmyLua luafmt is unavailable')
    directory = tmp_path / 'project with spaces'
    (directory / 'tools').mkdir(parents=True)
    (directory / 'source').mkdir()
    shutil.copy2(ROOT / 'tools/format_lua.py', directory / 'tools/format_lua.py')
    shutil.copy2(ROOT / 'luafmt.toml', directory / 'luafmt.toml')
    shutil.copy2(ROOT / '.luafmtignore', directory / '.luafmtignore')
    (directory / 'project.conf').write_text(f'luafmt = {executable}\n', encoding='utf-8')
    subprocess.run(['git', 'init', '-q', str(directory)], check=True, capture_output=True)
    return directory


def run(project, *arguments):
    return subprocess.run([sys.executable, str(project / 'tools/format_lua.py'), *arguments],
                          cwd=project.parent, capture_output=True, text=True, timeout=30)


def test_check_is_read_only_and_defaults_to_changed_files(project):
    source = b'local value={a=1,b=2}\nreturn value\n'
    selected = project / 'source/value.lua'
    selected.write_text('return true\n', encoding='utf-8')
    unrelated = project / 'unchanged.lua'
    unrelated.write_bytes(source)
    subprocess.run(['git', 'add', '--', 'source/value.lua', 'unchanged.lua'], cwd=project, check=True)
    # Establish the index as the baseline without requiring a temporary commit.
    tree = subprocess.run(['git', 'write-tree'], cwd=project, check=True, capture_output=True, text=True).stdout.strip()
    commit = subprocess.run(['git', '-c', 'user.name=Formatter test', '-c', 'user.email=format@example.invalid',
                             'commit-tree', tree, '-m', 'fixture'], cwd=project,
                            check=True, capture_output=True, text=True).stdout.strip()
    subprocess.run(['git', 'update-ref', 'HEAD', commit], cwd=project, check=True)
    selected.write_bytes(source)
    result = run(project, 'check', '--json')
    assert result.returncode == 1, result.stdout + result.stderr
    summary = json.loads(result.stdout)
    assert summary['changed_count'] == 1
    assert summary['error_count'] == 0
    assert selected.read_bytes() == unrelated.read_bytes() == source
    assert run(project, 'check').returncode == 1

    assert run(project, 'write').returncode == 0
    assert selected.read_bytes() != source
    assert unrelated.read_bytes() == source
    formatted = selected.read_bytes()
    assert run(project, 'check').returncode == 0
    assert run(project, 'write').returncode == 0
    assert selected.read_bytes() == formatted


def test_explicit_paths_use_repository_root_and_preserve_other_files(project):
    source = b'local value={a=1}\nreturn value\n'
    (project / 'source/value.lua').write_bytes(source)
    selected = project / 'other file.lua'
    selected.write_bytes(source)
    assert run(project, 'write', selected.name).returncode == 0
    assert run(project, 'check', '--json', selected.name).returncode == 0
    assert selected.read_bytes() != source
    assert (project / 'source/value.lua').read_bytes() == source


def test_recursive_scope_excludes_local_archives_and_generated_data(project):
    (project / 'source/value.lua').write_text('return true\n', encoding='utf-8')
    excluded = ('.plan/probe.lua', 'tmp/probe.lua', 'mpv-luatest/probe.lua',
                'meta/elxosc.lua', 'lib/fonts/fluent_icon_names.lua',
                'dev/design/old/example.lua')
    for name in excluded:
        path = project / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text('this is deliberately invalid Lua !\n', encoding='utf-8')
    result = run(project, 'check', '--json', '.')
    assert result.returncode == 0, result.stdout + result.stderr
    summary = json.loads(result.stdout)
    assert summary['error_count'] == summary['changed_count'] == 0
    assert summary['ok_count'] == 1


def test_invalid_lua_is_reported_without_overwriting_source(project):
    selected = project / 'source/invalid.lua'
    source = b'local broken = function(\n'
    selected.write_bytes(source)
    result = run(project, 'check', '--json')
    assert result.returncode != 0
    assert json.loads(result.stdout)['error_count'] == 1
    assert run(project, 'write').returncode != 0
    assert selected.read_bytes() == source


@pytest.mark.parametrize('arguments', [('check', '../outside.lua'), ('check', 'missing.lua'),
                                     ('check', 'project.conf'), ('write', '--json')])
def test_invalid_scope_or_mode_is_rejected(project, arguments):
    result = run(project, *arguments)
    assert result.returncode == 2


def test_missing_executable_reports_configuration_error(project):
    (project / 'project.conf').write_text('luafmt = missing-luafmt-test-executable\n', encoding='utf-8')
    (project / 'source/value.lua').write_text('return true\n', encoding='utf-8')
    result = run(project, 'check')
    assert result.returncode == 2
    assert 'configure luafmt in project.conf' in result.stderr


def test_default_selection_includes_staged_and_untracked_files(project):
    source = b'local value={a=1}\nreturn value\n'
    (project / 'staged.lua').write_bytes(source)
    subprocess.run(['git', 'add', '--', 'staged.lua'], cwd=project, check=True)
    (project / 'untracked.lua').write_bytes(source)
    (project / '.gitignore').write_text('ignored.lua\n', encoding='utf-8')
    (project / 'ignored.lua').write_bytes(source)
    result = run(project, 'check', '--json')
    assert result.returncode == 1
    summary = json.loads(result.stdout)
    assert summary['changed_count'] == 2
    assert {Path(name).name for name in summary['changed_files']} == {'staged.lua', 'untracked.lua'}


def test_empty_default_selection_succeeds_without_formatter(project):
    (project / 'project.conf').write_text('luafmt = missing-luafmt-test-executable\n', encoding='utf-8')
    result = run(project, 'check', '--json')
    assert result.returncode == 0
    assert json.loads(result.stdout)['ok_count'] == 0
