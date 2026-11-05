"""Offline ASS bounds reports using an ownership-bounded, isolated mpv host."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import math
import os
from pathlib import Path
import platform
import re
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'test' / 'real_host'))
import conftest as host_helpers


def validate_bundle(bundle):
    if not isinstance(bundle, dict) or type(bundle.get('schema_version')) is not int or bundle['schema_version'] != 1:
        raise ValueError('input schema_version must be 1')
    if not isinstance(bundle.get('scene'), str) or not bundle['scene']:
        raise ValueError('input scene must be a non-empty string')
    if type(bundle.get('scene_version')) is not int or bundle['scene_version'] < 1:
        raise ValueError('input scene_version must be a positive integer')
    samples = bundle.get('samples')
    if not isinstance(samples, list) or not 1 <= len(samples) <= 64:
        raise ValueError('input samples must contain 1 to 64 requests')
    names = set()
    for sample in samples:
        if not isinstance(sample, dict):
            raise ValueError('each sample must be an object')
        name, data = sample.get('name'), sample.get('data')
        if not isinstance(name, str) or not name or name in names:
            raise ValueError('sample names must be non-empty and unique')
        names.add(name)
        if not isinstance(data, str) or '\0' in data:
            raise ValueError('sample data must be a NUL-free string')
        for field in ('res_x', 'res_y'):
            value = sample.get(field)
            if type(value) is not int or not 0 < value <= 16384:
                raise ValueError(f'{field} must be an integer from 1 to 16384')
    return bundle


def wait_property(client, process, log, name, timeout):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if process.poll() is not None:
            raise RuntimeError(f'measurement host exited: {log.read_text(errors="replace")[-2000:]}')
        try:
            value = client.command('get_property', name, timeout=max(0.01, deadline - time.monotonic()))
        except AssertionError:
            value = None
        if value:
            return value
        time.sleep(min(0.05, max(0, deadline - time.monotonic())))
    raise TimeoutError(f'timed out waiting for {name}')


def wait_viewport(client, process, timeout):
    deadline = time.monotonic() + timeout
    previous, since = None, time.monotonic()
    while time.monotonic() < deadline:
        if process.poll() is not None:
            raise RuntimeError('measurement host exited before OSD initialization')
        dimensions = client.command('get_property', 'osd-dimensions',
                                    timeout=max(0.01, deadline - time.monotonic()))
        if dimensions != previous:
            previous, since = dimensions, time.monotonic()
        if dimensions and dimensions['w'] > 0 and dimensions['h'] > 0 and time.monotonic() - since >= 0.25:
            return dimensions
        time.sleep(0.05)
    raise TimeoutError('host OSD dimensions did not stabilize')


def measure(client, process, log, input_path='', repeats=3, timeout=5):
    wait_property(client, process, log, 'user-data/elxosc-ass-measure-ready', timeout)
    viewport = wait_viewport(client, process, timeout)
    # Readiness is separate from request completion. A timeout is never retried
    # as a new measurement; the owning fixture closes the isolated process tree.
    client.command('set_property', 'user-data/elxosc-ass-measure-report', '', timeout=timeout)
    client.command('script-message', 'elxosc-ass-measure', str(input_path), str(repeats), timeout=timeout)
    raw = wait_property(client, process, log, 'user-data/elxosc-ass-measure-report', timeout)
    report = json.loads(raw)
    report['status'] = 'error' if report.get('error') else 'ok'
    statuses = []
    for sample in report.get('samples', []):
        request = sample['request']
        protocol = {key: request[key] for key in ('data', 'res_x', 'res_y')}
        sample['payload_sha256'] = hashlib.sha256(request['data'].encode('utf-8')).hexdigest()
        sample['request_sha256'] = hashlib.sha256(json.dumps(protocol, sort_keys=True,
            ensure_ascii=False, separators=(',', ':')).encode('utf-8')).hexdigest()
        results = sample['results']
        sample['stable'] = bool(results) and all(
            (result['status'], result.get('bounds')) == (results[0]['status'], results[0].get('bounds'))
            for result in results)
        statuses.extend(result['status'] for result in results)
        if not sample['stable']:
            report.update(status='error', error=f'repeated bounds changed for {request["name"]}')
    if 'error' in statuses:
        report['status'] = 'error'
    elif 'unavailable' in statuses and report['status'] == 'ok':
        report['status'] = 'unavailable'
    environment = report.setdefault('environment', {})
    if environment.get('osd_dimensions') != viewport:
        report.update(status='error', error='OSD dimensions changed during measurement')
    environment.update(platform=platform.system(), architecture=platform.machine(),
        bounds_coordinate_space='ASS request resolution; not physical OSD pixels')
    lines = log.read_text(errors='replace').splitlines()
    environment['font_selection'] = list(dict.fromkeys(line for line in lines if 'fontselect:' in line))
    environment['libass_initialization'] = list(dict.fromkeys(line for line in lines if 'libass' in line
        and ('version' in line.lower() or 'shaper' in line.lower())))
    version = next((re.search(r'ASS library version: (0x[0-9a-fA-F]+) \(runtime (0x[0-9a-fA-F]+)\)',
        line) for line in environment['libass_initialization'] if 'ASS library version:' in line), None)
    environment['libass_version'] = ({'compiled_hex': version[1], 'runtime_hex': version[2]}
                                     if version else None)
    environment['libass_version_source'] = 'host libass log' if version else 'not exposed by host'
    font_file = ROOT / 'fonts' / 'MaterialSymbolsRounded-VariableFont_FILL,GRAD,opsz,wght.ttf'
    environment['bundled_font'] = {'file': f'fonts/{font_file.name}',
        'sha256': hashlib.sha256(font_file.read_bytes()).hexdigest()}
    revision = subprocess.run(['git', 'rev-parse', '--short', 'HEAD'], cwd=ROOT,
                              capture_output=True, text=True)
    environment['source_commit'] = revision.stdout.strip() if revision.returncode == 0 else None
    modified = subprocess.run(['git', 'status', '--porcelain', '--untracked-files=normal'],
                              cwd=ROOT, capture_output=True, text=True)
    environment['source_worktree_modified'] = bool(modified.stdout) if modified.returncode == 0 else None
    environment['source_files_sha256'] = {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest()
        for name in ('host/ass_measure.lua', 'tools/ass_measure_samples.lua', 'test/real_host/ass_measure.lua')}
    report['repeats'] = repeats
    report['generated_at_utc'] = datetime.now(timezone.utc).isoformat()
    report['limits'] = ['bounds may include renderer image padding; not exact glyph ink, baseline or optical-center metrics',
        'logical boxes and RecordCanvas operations are independent evidence',
        'hidden measurement does not prove displayed pixels or scan-out']
    return report


def markdown(report):
    lines = ['# ASS measurement', '', f'Status: `{report["status"]}`', '',
        '| Sample | Logical size | Host bounds | Stable |', '| --- | --- | --- | --- |']
    for sample in report.get('samples', []):
        request = sample['request']
        size = request.get('logical', {}).get('size', {})
        logical = f'{size["width"]} × {size["height"]}' if size else 'not supplied'
        result = sample['results'][0] if sample['results'] else {'status': 'error'}
        bounds = result.get('bounds')
        measured = (f'({bounds["left"]}, {bounds["top"]})–({bounds["right"]}, {bounds["bottom"]})'
                    if bounds else result['status'])
        name = request['name'].replace('|', '\\|').replace('\n', ' ')
        lines.append(f'| {name} | {logical} | {measured} | {sample["stable"]} |')
    if report.get('error'):
        lines.extend(['', report['error']])
    lines.extend(['', 'The JSON report retains payloads, hashes, resolution, fonts and repeat results.',
                  'Logical layout boxes and host bounds describe different quantities.', ''])
    return '\n'.join(lines)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input', type=Path, help='schema v1 JSON; omitted selects built-in framework samples')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--markdown', type=Path)
    parser.add_argument('--host', help='mpv/mpv.net binary; defaults to ELXOSC_MPV_BINARY or PATH')
    parser.add_argument('--repeats', type=int, default=3)
    parser.add_argument('--timeout', type=float, default=5)
    args = parser.parse_args(argv)
    if not 1 <= args.repeats <= 100 or not math.isfinite(args.timeout) or not 0 < args.timeout <= 60:
        parser.error('repeats must be 1..100 and timeout must be finite, >0 and <=60 seconds')
    if args.host:
        os.environ['ELXOSC_MPV_BINARY'] = args.host
    report = {'schema_version': 1, 'status': 'error'}
    try:
        bundle = validate_bundle(json.loads(args.input.read_text(encoding='utf-8'))) if args.input else None
        if not host_helpers.find_host():
            report.update(status='unavailable', error='mpv host executable unavailable')
        else:
            with tempfile.TemporaryDirectory(prefix='elxosc-ass-measure-') as directory:
                temporary = Path(directory)
                input_path = ''
                if bundle is not None:
                    input_path = temporary / 'input.json'
                    input_path.write_text(json.dumps(bundle, ensure_ascii=False), encoding='utf-8')
                script = ROOT / 'test' / 'real_host' / 'ass_measure.lua'
                with host_helpers._running_host(temporary, (f'--script={script}', '--force-window=yes',
                        '--geometry=640x360', f'--osd-fonts-dir={ROOT / "fonts"}',
                        '--msg-level=osd/libass=debug')) as (client, _, process, log):
                    report = measure(client, process, log, input_path, args.repeats, args.timeout)
    except (OSError, ValueError, RuntimeError, AssertionError, TimeoutError,
            host_helpers.pytest.fail.Exception) as error:
        report.update(status='error', error=str(error))
    report.setdefault('generated_at_utc', datetime.now(timezone.utc).isoformat())
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    if args.markdown:
        args.markdown.parent.mkdir(parents=True, exist_ok=True)
        args.markdown.write_text(markdown(report), encoding='utf-8')
    print(f'ASS measurement: {report["status"]}; {len(report.get("samples", []))} samples')
    return {'ok': 0, 'error': 1, 'unavailable': 2}[report['status']]


if __name__ == '__main__':
    raise SystemExit(main())
