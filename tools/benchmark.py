"""Framework phase baseline/comparison and optional real-host ASS measurement."""
import argparse
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
import os
import platform
from pathlib import Path
import shutil
import statistics
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('benchmark_measure_tool', ROOT / 'tools' / 'ass_measure.py')
measure_tool = importlib.util.module_from_spec(spec)
spec.loader.exec_module(measure_tool)


def executable(name):
    config = ROOT / 'project.conf'
    if config.is_file():
        for line in config.read_text(encoding='utf-8').splitlines():
            key, separator, value = line.partition('=')
            if separator and key.strip() == name:
                return value.strip()
    return shutil.which(name) or name


def metadata(paths):
    revision = subprocess.run(['git', 'rev-parse', 'HEAD'], cwd=ROOT, capture_output=True, text=True, check=True)
    modified = subprocess.run(['git', 'status', '--porcelain'], cwd=ROOT, capture_output=True, text=True, check=True)
    return {'source_commit': revision.stdout.strip(), 'source_worktree_modified': bool(modified.stdout),
            'source_sha256': {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in paths}}


def compare(current, baseline):
    keys = ('platform', 'architecture', 'runtime', 'jit_enabled', 'clock', 'processor')
    if (any(current['environment'].get(key) != baseline['environment'].get(key) for key in keys)
            or any(current[key] != baseline[key] for key in ('viewport', 'scene_version', 'iterations', 'warmup', 'rounds'))):
        raise ValueError('baseline environment, viewport, scene version or sampling differs')
    rows = []
    for group in ('scenarios', 'animation'):
        prior = {scene['name']: scene for scene in baseline[group]}
        if set(prior) != {scene['name'] for scene in current[group]}:
            raise ValueError(f'baseline scene set differs: {group}')
        for scene in current[group]:
            old = prior[scene['name']]
            if old['output_sha256'] != scene['output_sha256']:
                raise ValueError(f'baseline scene/output differs: {scene["name"]}')
            if set(old['phases']) != set(scene['phases']):
                raise ValueError(f'baseline phase set differs: {scene["name"]}')
            for phase, values in scene['phases'].items():
                previous = old['phases'][phase]['p50_ms']
                rows.append({'group': group, 'scene': scene['name'], 'phase': phase, 'baseline_p50_ms': previous,
                             'current_p50_ms': values['p50_ms'],
                             'ratio': values['p50_ms'] / previous if previous else None})
    return {'policy': 'descriptive same-environment ratios; no absolute budget or automatic pass threshold', 'rows': rows}


def core(iterations, warmup, rounds, directory):
    reports = []
    for index in range(rounds):
        output = directory / f'core-{index}.json'
        subprocess.run([executable('luajit'), 'tools/benchmark_core.lua', str(iterations), str(warmup), str(output)],
                       cwd=ROOT, check=True, capture_output=True, text=True)
        reports.append(json.loads(output.read_text(encoding='utf-8')))
    report = reports[0]
    report['environment']['processor'] = platform.processor() or os.environ.get('PROCESSOR_IDENTIFIER')
    report['rounds'] = rounds
    for group in ('scenarios', 'animation'):
        for index, scene in enumerate(report[group]):
            outputs = [item[group][index].pop('output_data') for item in reports]
            if any(output != outputs[0] for output in outputs):
                raise ValueError(f'output changed between rounds: {scene["name"]}')
            scene['output_sha256'] = hashlib.sha256(outputs[0].encode('utf-8')).hexdigest()
            for phase, values in scene['phases'].items():
                samples = [item[group][index]['phases'][phase].copy() for item in reports]
                values['rounds'] = samples
                values['p50_ms'] = statistics.median(item['p50_ms'] for item in samples)
                values['p95_ms'] = statistics.median(item['p95_ms'] for item in samples)
                values['round_p50_min_ms'] = min(item['p50_ms'] for item in samples)
                values['round_p50_max_ms'] = max(item['p50_ms'] for item in samples)
    report.update(metadata(('tools/benchmark_core.lua', 'tools/benchmark_scenes.lua',
                            'tools/benchmark_animation.lua', 'tools/benchmark_support.lua', 'tools/benchmark.py')))
    return report


def host(iterations, warmup, rounds, directory, legacy_ref):
    legacy = subprocess.run(['git', 'show', f'{legacy_ref}:host/ass_measure.lua'], cwd=ROOT,
                            capture_output=True, check=True).stdout
    legacy_file = directory / 'legacy-ass-measure.lua'
    legacy_file.write_bytes(legacy)
    script = ROOT / 'test' / 'real_host' / 'ass_measure_benchmark.lua'
    with measure_tool.host_helpers._running_host(directory / 'host', (f'--script={script}', '--force-window=yes',
            '--geometry=640x360', f'--osd-fonts-dir={ROOT / "fonts"}', '--msg-level=osd/libass=warn')) as (client, _, process, log):
        measure_tool.wait_property(client, process, log, 'user-data/elxosc-ass-benchmark-ready', 10)
        viewport = measure_tool.wait_viewport(client, process, 10)
        scenarios = []
        for name in ('text-latin', 'text-cjk', 'icon-play', 'scaled-text', 'clipped-text', 'composed-row', 'empty'):
            for mode in ('same', 'changed'):
                client.command('set_property', 'user-data/elxosc-ass-benchmark-report', '')
                client.command('script-message', 'elxosc-ass-benchmark', str(legacy_file), str(iterations),
                               str(warmup), str(rounds), name, mode)
                raw = measure_tool.wait_property(client, process, log, 'user-data/elxosc-ass-benchmark-report', 60)
                report = json.loads(raw)
                if report['status'] != 'ok':
                    raise RuntimeError(report.get('error') or report.get('cleanup_error'))
                scenarios.extend(report['scenarios'])
                print(f'host benchmark: {name}/{mode}', flush=True)
        report['scenarios'] = scenarios
        if report['environment']['osd_dimensions'] != viewport:
            raise RuntimeError('OSD changed during host benchmark')
        lines = log.read_text(errors='replace').splitlines()
        report['environment']['font_selection'] = list(dict.fromkeys(line for line in lines if 'fontselect:' in line))
        report['environment']['libass_initialization'] = list(dict.fromkeys(line for line in lines if 'libass' in line
            and ('version' in line.lower() or 'shaper' in line.lower())))
    for scene in report['scenarios']:
        scene['payload_sha256'] = [hashlib.sha256(value.encode('utf-8')).hexdigest() for value in scene.pop('payloads')]
        for variant in scene['variants'].values():
            variant['p50_ms'] = statistics.median(item['distribution']['p50_ms'] for item in variant['rounds'])
            variant['p95_ms'] = statistics.median(item['distribution']['p95_ms'] for item in variant['rounds'])
        old = scene['variants']['legacy']['p50_ms']
        for variant in scene['variants'].values():
            variant['ratio_to_legacy'] = variant['p50_ms'] / old if old else None
    report.update(metadata(('host/ass_measure.lua', 'test/real_host/ass_measure_benchmark.lua',
                            'tools/ass_measure_samples.lua', 'tools/benchmark_support.lua', 'tools/benchmark.py')))
    report['legacy'] = {'git_ref': legacy_ref, 'file': 'host/ass_measure.lua',
                        'sha256': hashlib.sha256(legacy).hexdigest()}
    report['environment']['libass_logging'] = 'warn during timed batches; font/version evidence uses separate calibration'
    report['limits'] = ['Lua plus synchronous native/libass time; no IPC inside timed iterations',
                        'legacy timing includes its original validation/report conversion',
                        'heap delta is live heap change, not cumulative allocation',
                        'no bounds result cache; cold requests and init/dispose reported separately',
                        'all strategies compared for identical bounds before timing; no scan-out measurement']
    return report


def markdown(report):
    lines = ['# Framework and ASS benchmark', '', f'Generated: {report["generated_at_utc"]}', '',
             'Core values are medians of per-round p50 values, in milliseconds.', '',
             '| Scene | Nodes (Element/Render) | Reconcile | Dirty rebuild | Dirty layout | ASS paint |',
             '| --- | --- | --- | --- | --- | --- |']
    for scene in report['core']['scenarios']:
        values = [f'{scene["phases"][phase]["p50_ms"]:.4f}' for phase in ('reconcile', 'dirty_rebuild', 'layout_dirty', 'ass_paint')]
        lines.append(f'| {scene["name"]} | {scene["elements"]}/{scene["render_objects"]} | ' + ' | '.join(values) + ' |')
    lines.extend(['', 'Paint-only animation at simulated 240 Hz; cached Record replay is a staging experiment.', '',
                  '| Scene | Ticker | Full paint | Record replay | Layout frames |',
                  '| --- | --- | --- | --- | --- |'])
    for scene in report['core']['animation']:
        values = [f'{scene["phases"][phase]["p50_ms"]:.4f}' for phase in ('ticker', 'full_paint', 'record_replay')]
        lines.append(f'| {scene["name"]} | ' + ' | '.join(values) + f' | {scene["layout_frames"]} |')
    if 'host' in report:
        lines.extend(['', 'Host values include synchronous native/libass work; no timed IPC.', '',
                      '| Sample | Payload | Legacy | Overlay update | Native reuse | Reuse/legacy |',
                      '| --- | --- | --- | --- | --- | --- |'])
        for scene in report['host']['scenarios']:
            variants = scene['variants']
            values = [f'{variants[name]["p50_ms"]:.4f}' for name in ('legacy', 'overlay_update', 'native_reuse')]
            lines.append(f'| {scene["name"]} | {scene["mode"]} | ' + ' | '.join(values)
                         + f' | {variants["native_reuse"]["ratio_to_legacy"]:.3f} |')
    if 'comparison' in report:
        lines.extend(['', 'Comparison ratios are descriptive; full phase/round details are in JSON.'])
    lines.extend(['', 'Record replay and direct ASS bytes are checked each iteration; host bounds are checked before timings.',
                  'CPU/OS load, JIT, GC and libass caches affect the distribution. No cross-machine budget is asserted.', ''])
    return '\n'.join(lines)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--markdown', type=Path)
    parser.add_argument('--baseline', type=Path)
    parser.add_argument('--iterations', type=int, default=100)
    parser.add_argument('--warmup', type=int, default=30)
    parser.add_argument('--rounds', type=int, default=3)
    parser.add_argument('--host-measure', action='store_true')
    parser.add_argument('--host', help='mpv/mpv.net executable')
    parser.add_argument('--host-iterations', type=int, default=50)
    parser.add_argument('--host-warmup', type=int, default=10)
    parser.add_argument('--legacy-ref', default='46bc4a2')
    args = parser.parse_args(argv)
    if (not 1 <= args.iterations <= 10000 or not 0 <= args.warmup <= 10000 or not 1 <= args.rounds <= 20
            or not 1 <= args.host_iterations <= 1000 or not 0 <= args.host_warmup <= 1000):
        parser.error('iterations/warmup/rounds exceed supported batch bounds')
    if args.host:
        os.environ['ELXOSC_MPV_BINARY'] = args.host
    with tempfile.TemporaryDirectory(prefix='elxosc-benchmark-') as temporary:
        directory = Path(temporary)
        report = {'schema_version': 1, 'generated_at_utc': datetime.now(timezone.utc).isoformat(),
                  'core': core(args.iterations, args.warmup, args.rounds, directory)}
        if args.host_measure:
            if not measure_tool.host_helpers.find_host():
                raise RuntimeError('real host unavailable; run core without --host-measure')
            (directory / 'host').mkdir()
            report['host'] = host(args.host_iterations, args.host_warmup, args.rounds, directory, args.legacy_ref)
        if args.baseline:
            baseline = json.loads(args.baseline.read_text(encoding='utf-8'))
            report['comparison'] = compare(report['core'], baseline['core'])
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    if args.markdown:
        args.markdown.parent.mkdir(parents=True, exist_ok=True)
        args.markdown.write_text(markdown(report), encoding='utf-8')
    print(f'benchmark: {len(report["core"]["scenarios"])} core scenarios; host={"host" in report}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
