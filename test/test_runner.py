"""Exercise the actual Lua CLI in a standalone, disposable test tree."""
import os
from pathlib import Path
import shutil
import subprocess

import pytest


ROOT = Path(__file__).resolve().parents[1]


@pytest.fixture
def suite(tmp_path):
    executable = os.environ.get("ELXOSC_LUAJIT") or shutil.which("luajit")
    if not executable and (ROOT / "project.conf").exists():
        for line in (ROOT / "project.conf").read_text(encoding="utf-8").splitlines():
            key, separator, value = line.partition("=")
            if separator and key.strip() == "luajit":
                executable = shutil.which(value.strip())
    if not executable:
        pytest.skip("LuaJIT is unavailable")
    directory = tmp_path / "suite with spaces" / "test"
    directory.mkdir(parents=True)
    for name in ("run.lua", "runner.lua", "framework.lua", "support.lua"):
        shutil.copy2(ROOT / "test" / name, directory / name)
    return executable, directory


def write_test(directory, name, body):
    path = directory / name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("local F = require 'framework'\nF.section('fixture')\n" + body,
                    encoding="utf-8")


def run(suite, *args):
    executable, directory = suite
    return subprocess.run([executable, "run.lua", *args], cwd=directory,
                          capture_output=True, text=True, timeout=30)


@pytest.mark.parametrize("selector", ["player/layout", "test_player/test_layout.lua",
                                     "player", "layout", "player\\layout"])
def test_recursive_selection(suite, selector):
    _, directory = suite
    write_test(directory, "test_outer/test_player/test_layout.lua", "F.ok(true, 'nested')")
    write_test(directory, "test_unrelated.lua", "F.fail('unselected')")
    write_test(directory, "fixtures/test_player/test_layout.lua", "F.fail('fixture')")
    result = run(suite, selector)
    assert result.returncode == 0, result.stdout + result.stderr
    assert "ALL GOOD: 1 checks passed" in result.stdout
    assert "== fixture ==" not in result.stdout
    assert "elxosc test-suite" not in result.stdout


def test_default_discovery_and_verbose(suite):
    _, directory = suite
    write_test(directory, "test_z.lua", "F.test('last', function() F.ok(true, 'z') end)")
    write_test(directory, "test_player/test_layout.lua",
               "F.test('nested', function() F.ok(true, 'layout') end)")
    write_test(directory, "real_host/test_ignored.lua", "F.fail('host fixture')")
    result = run(suite, "-v")
    assert result.returncode == 0, result.stdout + result.stderr
    assert "ALL GOOD: 2 checks passed" in result.stdout
    assert "ok    nested" in result.stdout
    assert result.stdout.index("test_player/test_layout.lua") < result.stdout.index("test_z.lua")
    assert "== fixture ==" in result.stdout
    assert run(suite, "player/layout", "-v").returncode == 0


@pytest.mark.parametrize("verbose", [False, True])
def test_assertion_failure_is_never_reported_as_success(suite, verbose):
    _, directory = suite
    write_test(directory, "test_bad.lua", "F.test('broken', function() F.eq(1, 2, 'value') end)")
    write_test(directory, "test_next.lua", "F.ok(true, 'still runs')")
    result = run(suite, *(["-v"] if verbose else []))
    assert result.returncode == 1
    assert "test_bad.lua / fixture / broken" in result.stdout
    assert "ok    broken" not in result.stdout
    assert "FAILED: 1 failure(s), 1 check(s) passed" in result.stdout


def test_file_errors_keep_the_path_and_continue(suite):
    _, directory = suite
    write_test(directory, "test_bad.lua", "this is not lua!")
    write_test(directory, "test_next.lua", "F.ok(true, 'still runs')")
    result = run(suite)
    assert result.returncode == 1
    assert "test_bad.lua crashed" in result.stdout
    assert "1 check(s) passed" in result.stdout


@pytest.mark.parametrize("args, message", [(["missing"], "no test file matched"),
                                          (["--unknown"], "unknown option"),
                                          (["one", "two"], "at most one"),
                                          ([""], "must not be empty")])
def test_invalid_invocations_fail(suite, args, message):
    _, directory = suite
    write_test(directory, "test_ok.lua", "F.ok(true, 'ok')")
    result = run(suite, *args)
    assert result.returncode == 1
    assert message in result.stdout


def test_help_and_absolute_entrypoint(suite):
    executable, directory = suite
    assert "Usage:" in run(suite, "--help").stdout
    write_test(directory, "test_ok.lua", "F.ok(true, 'ok')")
    result = subprocess.run([executable, str(directory / "run.lua")], cwd=directory.parent,
                            capture_output=True, text=True, timeout=30)
    assert result.returncode == 0, result.stdout + result.stderr
