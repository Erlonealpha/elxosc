"""Run the configured EmmyLua formatter on changed Lua files or explicit paths."""

import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]


def formatter_executable():
    config = ROOT / 'project.conf'
    if config.is_file():
        for line in config.read_text(encoding='utf-8-sig').splitlines():
            key, separator, value = line.partition('=')
            if separator and key.strip() == 'luafmt' and value.strip():
                return value.strip()
    return shutil.which('luafmt') or 'luafmt'


def changed_lua_paths():
    commands = (
        ['git', 'ls-files', '--modified', '--others', '--exclude-standard', '-z'],
        ['git', 'diff', '--cached', '--name-only', '--diff-filter=ACMR', '-z'],
    )
    names = set()
    for command in commands:
        result = subprocess.run(command, cwd=ROOT, check=True, capture_output=True,
                                text=True, encoding='utf-8')
        names.update(name for name in result.stdout.split('\0') if name)
    return sorted(name for name in names if name.endswith('.lua') and (ROOT / name).is_file())


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=('check', 'write'))
    parser.add_argument('paths', nargs='*', help='repository paths; default: changed Lua files')
    parser.add_argument('--json', action='store_true', help='JSON summary for check mode')
    args = parser.parse_args(argv)
    if args.json and args.mode != 'check':
        parser.error('--json requires check mode')

    try:
        selected = args.paths or changed_lua_paths()
    except (OSError, subprocess.CalledProcessError) as error:
        print(f'cannot discover changed Lua files: {error}; pass explicit paths', file=sys.stderr)
        return 2
    if not selected:
        if args.json:
            print(json.dumps({'changed_count': 0, 'changed_files': [], 'error_count': 0,
                              'error_files': [], 'ok_count': 0}))
        else:
            print('No changed Lua files.')
        return 0

    paths = []
    for value in selected:
        path = (ROOT / value).resolve()
        if not path.is_relative_to(ROOT):
            parser.error(f'path is outside the repository: {value}')
        if not path.exists():
            parser.error(f'path does not exist: {value}')
        if path.is_file() and path.suffix != '.lua':
            parser.error(f'expected a Lua file or directory: {value}')
        paths.append(path.relative_to(ROOT).as_posix())

    command = [formatter_executable(), '--config', str(ROOT / 'luafmt.toml'), '--recursive']
    if args.mode == 'write':
        command.extend(('--write', '--verify'))
    else:
        command.append('--check')
        if args.json:
            command.append('--json')
    command.extend(paths)
    try:
        if args.json:
            result = subprocess.run(command, cwd=ROOT, check=False, capture_output=True,
                                    text=True, encoding='utf-8')
            print(result.stdout, end='')
            print(result.stderr, end='', file=sys.stderr)
            if result.returncode != 0:
                return result.returncode
            # luafmt 0.25.1 returns 0 for JSON format differences; enforce the gate.
            summary = json.loads(result.stdout)
            if summary['error_count']:
                return 2
            return 1 if summary['changed_count'] else 0
        return subprocess.run(command, cwd=ROOT, check=False).returncode
    except (json.JSONDecodeError, KeyError) as error:
        print(f'invalid luafmt JSON summary: {error}', file=sys.stderr)
        return 2
    except OSError as error:
        print(f'cannot run luafmt: {error}; configure luafmt in project.conf', file=sys.stderr)
        return 2


if __name__ == '__main__':
    sys.exit(main())
