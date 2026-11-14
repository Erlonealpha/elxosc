"""Framework collectors run with no player, Define or mpv on the search path."""
import os
import re
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
    orders = []
    for first in ('widgets', 'foundation', 'animation', 'render'):
        result = subprocess.run(
            [executable, str(ROOT / 'test' / 'fixtures' / 'framework_packages.lua'),
             str(tmp_path), str(dependency)],
            cwd=tmp_path, capture_output=True, text=True, timeout=30,
            env={**os.environ, 'ELXOSC_TEST_PACKAGE_FIRST': first},
        )
        assert result.returncode == 0, result.stdout + result.stderr
        assert 'framework mount/paint/input/dispose passed' in result.stdout
        orders.append(next(line for line in result.stdout.splitlines() if line.startswith('framework catalog: ')))
    assert len(set(orders)) == 1, 'framework catalog changed with require order'


def test_static_catalogs_cover_every_runtime_module():
    """Filesystem audits run in development; runtime catalogs remain explicit."""
    for owner in ('lib', 'player', 'define'):
        catalog = ROOT / owner / 'package_catalog.lua'
        content = catalog.read_text(encoding='utf-8')
        declarations = re.findall(r"(?:exports\.)?export\('([^']+)', require '([^']+)'\)", content)
        names = [name for name, _ in declarations]
        assert len(names) == len(set(names)), f'duplicate {owner} package name'
        mapping = dict(declarations)
        inventory = {catalog}
        if owner == 'lib':
            inventory.update((ROOT / owner).glob('*.lua'))
            inventory.update((ROOT / owner / 'fonts').glob('*.lua'))
        inventory.update((ROOT / owner / 'src').rglob('*.lua'))
        if owner != 'lib':
            inventory.add(ROOT / owner / 'init.lua')
        for path in inventory:
            if path.name == 'fluent_icon_names.lua':
                continue  # Annotation-only metadata, not a Lua runtime module.
            relative = path.relative_to(ROOT / owner).with_suffix('')
            if path.name == 'init.lua':
                parts = relative.parts[:-1]
                if owner == 'lib':
                    name = parts[-1]
                else:
                    name = owner
                assert name in mapping, f'missing alias target for {path}'
                continue
            require_name = '.'.join(relative.parts)
            name = require_name.removeprefix('src.')
            if owner != 'lib':
                require_name = f'{owner}.{require_name}'
                name = f'{owner}.{name}'
            if path == catalog:
                assert re.search(rf"(?:exports\.)?export\('{re.escape(name)}', M\)", content)
            else:
                assert mapping.get(name) == require_name, f'missing or wrong mapping for {path}'
