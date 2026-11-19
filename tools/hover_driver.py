"""Shared direct-pointer behavior validation on bare LuaJIT and an isolated real host."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'test/real_host'))
import conftest as host_helpers

SCENES = ('paused-fixed', 'paused-ms', 'playing', 'stationary', 'burst', 'clean',
          'data-pressure', 'environment', 'preview')
MAX_REPORT_BYTES = 64 * 1024 * 1024


def executable(name):
    config = ROOT / 'project.conf'
    if config.is_file():
        for line in config.read_text(encoding='utf-8').splitlines():
            key, separator, value = line.partition('=')
            if separator and key.strip() == name:
                return value.strip()
    return shutil.which(name) or name


def read_report(path):
    if path.stat().st_size > MAX_REPORT_BYTES:
        raise ValueError('hover report exceeds byte limit')
    return json.loads(path.read_text(encoding='utf-8'))


def run_lua(scene, frames, directory, timeout):
    output = directory / f'lua-{scene}.json'
    subprocess.run([executable('luajit'), 'tools/hover_driver_lua.lua', scene, str(frames), str(output)],
                   cwd=ROOT, check=True, timeout=timeout, capture_output=True, text=True)
    return read_report(output)


def wait_property(client, process, log, name, timeout):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if process.poll() is not None:
            raise RuntimeError(f'hover host exited: {log.read_text(errors="replace")[-2000:]}')
        try:
            value = client.command('get_property', name, timeout=max(.01, deadline - time.monotonic()))
        except AssertionError:
            value = None
        if value:
            return value
        time.sleep(.02)
    raise TimeoutError(f'hover driver timed out waiting for {name}')


def run_host(client, process, log, scene, frames, directory, timeout):
    output = directory / f'host-{scene}.json'
    client.command('set_property', 'user-data/elxosc-hover-driver-result', '', timeout=timeout)
    client.command('script-message', 'elxosc-hover-driver', scene, str(frames), str(output), timeout=timeout)
    value = wait_property(client, process, log, 'user-data/elxosc-hover-driver-result', timeout)
    if value != 'ok':
        raise RuntimeError(value)
    return read_report(output)


def validate(report):
    trace, counts = report['trace'], report['counts']
    if report['schema_version'] != 1 or trace['schema_version'] != 1:
        raise ValueError('unsupported hover schema')
    if len(report['frames']) != trace['frames'] or len(trace['steps']) != trace['frames']:
        raise ValueError('frame checkpoint count differs')
    events = sum(len(step['moves']) for step in trace['steps'])
    if events != report['pointer_events']:
        raise ValueError('pointer event conservation failed')
    if sum(bool(step.get('state')) for step in trace['steps']) != report['state_batches']:
        raise ValueError('state batch conservation failed')
    if counts['emitted'] != counts['callbacks'] or counts['updates'] > counts['present']:
        raise ValueError('actual frame/update count differs')
    if counts['requested'] + counts['pending_initial'] != counts['emitted'] + counts['pending_end']:
        raise ValueError('requested timer conservation failed')
    if counts['paint'] != counts['present'] or counts['callbacks'] > trace['frames']:
        raise ValueError('paint/present pipeline differs')
    if trace['name'] in ('paused-fixed', 'paused-ms', 'playing', 'burst', 'data-pressure', 'environment', 'preview'):
        if counts['callbacks'] != trace['frames'] or trace['frames'] and not counts['paint']:
            raise ValueError('hover did not execute requested production frames')
        if trace['frames'] and not any(frame['tooltips'] for frame in report['frames']):
            raise ValueError('hover missed the actual timeline Tooltip')
    if any(report['cleanup'].values()):
        raise ValueError('driver resources not released')
    if report['cleanup_state'] != {'root_detached': True, 'clock_handler_removed': True, 'scheduled': False}:
        raise ValueError('driver owner/clock not detached')
    return report


def compare(lua, host):
    validate(lua)
    validate(host)
    for key in ('trace', 'frames', 'pointer_events', 'state_batches', 'counts', 'cleanup',
                'cleanup_actions', 'cleanup_state'):
        if lua[key] != host[key]:
            if key == 'frames':
                for index, (left, right) in enumerate(zip(lua[key], host[key])):
                    if left != right:
                        raise ValueError(f'first behavior divergence: frame {index + 1}')
            raise ValueError(f'behavior divergence: {key}')
    raw = host['native_raster']
    final_ass = host['frames'][-1]['ass'] if host['frames'] else ''
    if final_ass and (not isinstance(raw, dict) or raw.get('x1', 0) <= raw.get('x0', 0)
                           or raw.get('y1', 0) <= raw.get('y0', 0)):
        raise ValueError('real-host raster bounds missing')
    if not final_ass and raw not in ({}, []):
        raise ValueError('empty frame produced nonempty raster bounds')
    return {'equivalent': True, 'frames': len(lua['frames']),
            'trace_sha256': hashlib.sha256(json.dumps(lua['trace'], sort_keys=True).encode()).hexdigest(),
            'behavior_sha256': hashlib.sha256(json.dumps(lua['frames'], sort_keys=True).encode()).hexdigest()}


def source_manifest():
    sources = {}
    for directory in ('lib', 'host', 'player', 'define'):
        for path in sorted((ROOT / directory).rglob('*.lua')):
            sources[path.relative_to(ROOT).as_posix()] = hashlib.sha256(path.read_bytes()).hexdigest()
    for path in sorted((ROOT / 'tools').glob('hover_driver*')):
        if path.is_file():
            sources[path.relative_to(ROOT).as_posix()] = hashlib.sha256(path.read_bytes()).hexdigest()
    for name in ('test/real_host/hover_driver.lua', 'test/real_host/conftest.py', 'test/real_host/lifecycle.py',
                 'test/support.lua', 'test/dependency.lua'):
        sources[name] = hashlib.sha256((ROOT / name).read_bytes()).hexdigest()
    dependency = {}
    for path in sorted((ROOT.parent / 'elxlib/elxlibs').rglob('*.lua')):
        dependency[path.relative_to(ROOT.parent / 'elxlib').as_posix()] = hashlib.sha256(path.read_bytes()).hexdigest()
    revision = subprocess.run(['git', 'rev-parse', 'HEAD'], cwd=ROOT, check=True, capture_output=True, text=True)
    dependency_commit = subprocess.run(['git', '-c', f'safe.directory={(ROOT.parent / "elxlib").as_posix()}',
                                       'rev-parse', 'HEAD'], cwd=ROOT.parent / 'elxlib', check=True,
                                      capture_output=True, text=True).stdout.strip()
    fonts = {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
             for p in sorted((ROOT / 'lib/fonts').glob('*.ttf'))}
    return {'elxosc_commit': revision.stdout.strip(), 'source_sha256': sources,
            'elxlib_commit': dependency_commit, 'elxlib_sha256': dependency, 'font_sha256': fonts}


def run(scenes, frames, adapter, timeout):
    manifest = source_manifest()
    results = []
    with tempfile.TemporaryDirectory(prefix='elxosc-hover-driver-') as temporary:
        directory = Path(temporary)
        lua_reports = {scene: run_lua(scene, frames, directory, timeout) for scene in scenes} if adapter != 'host' else {}
        if adapter != 'lua':
            if not host_helpers.find_host():
                raise RuntimeError('real host unavailable')
            with host_helpers._running_host(directory, (
                    f'--script={ROOT / "test/real_host/hover_driver.lua"}', '--force-window=yes',
                    '--geometry=1280x720', '--osd-level=0', f'--osd-fonts-dir={ROOT / "lib/fonts"}')) as (client, _, process, log):
                wait_property(client, process, log, 'user-data/elxosc-hover-driver-ready', timeout)
                for scene in scenes:
                    host = validate(run_host(client, process, log, scene, frames, directory, timeout))
                    result = {'scene': scene, 'host': host}
                    if adapter == 'both':
                        result.update(lua=lua_reports[scene], parity=compare(lua_reports[scene], host))
                    results.append(result)
            if process.poll() is None:
                raise RuntimeError('owned real host did not exit')
        else:
            results = [{'scene': scene, 'lua': validate(lua_reports[scene])} for scene in scenes]
    if manifest != source_manifest():
        raise RuntimeError('source/dependency changed during validation')
    return {'schema_version': 1, 'status': 'ok', 'purpose': 'HP-0 behavior validation, no performance timings',
            'source': manifest, 'scenes': results, 'owned_host_exited': adapter != 'lua'}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--scenes', nargs='+', choices=SCENES, default=list(SCENES))
    parser.add_argument('--frames', type=int, default=16)
    parser.add_argument('--adapter', choices=('lua', 'host', 'both'), default='both')
    parser.add_argument('--timeout', type=float, default=20)
    parser.add_argument('--host')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args(argv)
    if not 0 <= args.frames <= 512 or not .1 <= args.timeout <= 60:
        parser.error('frames must be 0..512 and timeout .1..60 seconds')
    if args.host:
        os.environ['ELXOSC_MPV_BINARY'] = args.host
    elif not os.environ.get('ELXOSC_MPV_BINARY'):
        configured = executable('mpv')
        if shutil.which(configured):
            os.environ['ELXOSC_MPV_BINARY'] = configured
    try:
        report = run(args.scenes, args.frames, args.adapter, args.timeout)
    except (OSError, RuntimeError, ValueError, subprocess.SubprocessError) as error:
        report = {'schema_version': 1, 'status': 'error', 'error': str(error)}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    encoded = json.dumps(report, ensure_ascii=False, indent=2) + '\n'
    if len(encoded.encode()) > MAX_REPORT_BYTES:
        report = {'schema_version': 1, 'status': 'error', 'error': 'report exceeds byte limit'}
        encoded = json.dumps(report) + '\n'
    args.output.write_text(encoded, encoding='utf-8')
    print(report['status'])
    return 0 if report['status'] == 'ok' else 1


if __name__ == '__main__':
    raise SystemExit(main())
