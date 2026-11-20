"""Separated hover baseline, phase/count/sample/GC rounds and native replay validation."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import statistics
import tempfile

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('hover_measure_driver', ROOT / 'tools/hover_driver.py')
driver = importlib.util.module_from_spec(spec)
spec.loader.exec_module(driver)
MODES = ('baseline', 'phase', 'class-count', 'table-sites', 'sample-function', 'sample-line', 'gc', 'gc-off')


def check_work(validation, measured):
    for key in ('pointer_events', 'state_batches', 'counts', 'cleanup', 'cleanup_state'):
        if validation[key] != measured[key]:
            raise ValueError(f'measurement workload changed: {key}')
    if validation['frames'] and validation['frames'][-1]['ass'] != measured['frames'][-1]['ass']:
        raise ValueError('measurement final ASS changed')


def compact(report):
    return {key: report[key] for key in ('mode', 'warmup', 'counts', 'service', 'service_total_seconds',
            'heap', 'profiling', 'runtime', 'cleanup', 'cleanup_state', 'measurement')}


def summarize(rounds):
    baselines = [report['service']['mean_ms'] for report in rounds['baseline']]
    center = statistics.median(baselines)
    spread = (max(baselines) - min(baselines)) / center if center else 0
    modes = {}
    for mode, reports in rounds.items():
        average = statistics.median(report['service']['mean_ms'] for report in reports)
        modes[mode] = {'median_round_mean_ms': average,
                      'median_round_p95_ms': statistics.median(report['service']['p95_ms'] for report in reports),
                      'relative_to_baseline': average / center if center else None}
    return {'modes': modes, 'baseline_mean_range_ms': [min(baselines), max(baselines)],
            'baseline_relative_range': spread,
            'pre_candidate_gate': {'mean_improvement_fraction': max(.05, spread),
                                   'regression_tolerance_fraction': max(.05, spread),
                                   'policy': 'repeat >=3 interleaved A/B rounds; improvement in all rounds beyond registered noise, no key-scene regression; noisy gate requires more baseline rounds'}}


def run(scenes, modes, frames, warmup, rounds, adapter, timeout, checkpoint_path=None, trace_options=None):
    source = driver.source_manifest()
    results = []
    with tempfile.TemporaryDirectory(prefix='elxosc-hover-measure-') as temporary:
        directory = Path(temporary)
        for scene in scenes:
            validations = {}
            all_rounds = {kind: {mode: [] for mode in modes} for kind in ('lua', 'host')}
            # Fresh host process per measurement mode/round: no table-site or profiler
            # module cache can leak to a baseline. Runs are deliberately sequential.
            for round_index in range(rounds):
                for mode in modes:
                    options = {'mode': mode, 'warmup': warmup, 'trace_options': trace_options or {} }
                    if adapter in ('lua', 'both'):
                        if 'lua' not in validations:
                            validations['lua'] = driver.run_lua(scene, frames, directory, timeout,
                                                               {'mode': 'validation', 'warmup': warmup,
                                                                'trace_options': trace_options or {} })
                        measured = driver.run_lua(scene, frames, directory, timeout, options)
                        check_work(validations['lua'], measured)
                        all_rounds['lua'][mode].append(compact(measured))
                    if adapter in ('host', 'both'):
                        folder = directory / f'host-{scene}-{mode}-{round_index}'
                        folder.mkdir()
                        with driver.host_helpers._running_host(folder, (
                                f'--script={ROOT / "test/real_host/hover_driver.lua"}', '--force-window=yes',
                                '--geometry=1280x720', '--osd-level=0',
                                f'--osd-fonts-dir={ROOT / "lib/fonts"}'), quiet=True) as (client, _, process, log):
                            driver.wait_property(client, process, log, 'user-data/elxosc-hover-driver-ready', timeout)
                            measured = driver.run_host(client, process, log, scene, frames, folder, timeout, options)
                        if process.poll() is None:
                            raise RuntimeError('owned measurement host did not exit')
                        if 'host' not in validations:
                            # Independent fresh validation prevents importing instrumented modules.
                            folder = directory / f'validation-{scene}'
                            folder.mkdir()
                            with driver.host_helpers._running_host(folder, (
                                    f'--script={ROOT / "test/real_host/hover_driver.lua"}', '--force-window=yes',
                                    '--geometry=1280x720', '--osd-level=0',
                                    f'--osd-fonts-dir={ROOT / "lib/fonts"}'), quiet=True) as (client, _, process, log):
                                driver.wait_property(client, process, log, 'user-data/elxosc-hover-driver-ready', timeout)
                                validations['host'] = driver.run_host(client, process, log, scene, frames, folder, timeout,
                                                                     {'mode': 'validation', 'warmup': warmup,
                                                                      'trace_options': trace_options or {} })
                        check_work(validations['host'], measured)
                        all_rounds['host'][mode].append(compact(measured))
                    print(f'{scene} round {round_index + 1}/{rounds} {mode} complete', flush=True)
            if len(validations) == 2:
                driver.compare(validations['lua'], validations['host'])
                for mode, field in (('class-count', 'constructors'), ('table-sites', 'table_sites')):
                    if mode in modes:
                        for index in range(rounds):
                            left = all_rounds['lua'][mode][index]['profiling'][field]
                            right = all_rounds['host'][mode][index]['profiling'][field]
                            if left != right:
                                differing = next((key for key in set(left) | set(right) if left.get(key) != right.get(key)), '?')
                                raise ValueError(f'Lua/host {mode} counts or definitions differ: {scene}/{differing}: '
                                                 f'{left.get(differing)} / {right.get(differing)}')
            results.append({'scene': scene, 'validation_counts': {k: v['counts'] for k, v in validations.items()},
                            'behavior_sha256': {k: hashlib.sha256(json.dumps(v['frames'], sort_keys=True).encode()).hexdigest()
                                                for k, v in validations.items()},
                            'adapters': {kind: {'rounds': data, 'summary': summarize(data)}
                                         for kind, data in all_rounds.items() if data['baseline']}})
            if checkpoint_path:
                checkpoint_path.parent.mkdir(parents=True, exist_ok=True)
                checkpoint_path.write_text(json.dumps({'schema_version': 1, 'status': 'partial',
                    'source': source, 'scenes': results}, ensure_ascii=False) + '\n', encoding='utf-8')
    if source != driver.source_manifest():
        raise RuntimeError('source or dependency changed during measurement')
    return {'schema_version': 1, 'status': 'ok', 'frames': frames, 'warmup': warmup, 'rounds': rounds,
            'host_launch': 'quiet: minimized, no focus, no console; real VO/presenter/libass',
            'source': source, 'scenes': results,
            'limits': 'source constructor/site events are not physical allocations; modes include probe cost; native replay/paced checks independent; no scanout'}


def native_pair(scene, frames, warmup, directory, timeout, paced=False):
    folder = directory / ('paced' if paced else 'record')
    folder.mkdir()
    with driver.host_helpers._running_host(folder, (
            f'--script={ROOT / "test/real_host/hover_driver.lua"}', '--force-window=yes', '--geometry=1280x720',
            '--osd-level=0', '--osd-font=Arial', f'--osd-fonts-dir={ROOT / "lib/fonts"}'), quiet=True) as (client, _, process, log):
        driver.wait_property(client, process, log, 'user-data/elxosc-hover-driver-ready', timeout)
        host = driver.run_host(client, process, log, scene, frames, folder, timeout,
                               {'mode': 'validation', 'warmup': warmup, 'text_mode': 'record', 'paced': paced})
    corpus = host['native_requests']
    lua = driver.run_lua(scene, frames, directory, timeout,
                         {'mode': 'validation', 'warmup': warmup, 'text_mode': 'replay', 'corpus': corpus})
    driver.compare(lua, host)
    if lua['replay_requests'] != len(corpus):
        raise ValueError('native replay request count differs')
    return {'scene': scene, 'paced': paced, 'requests': len(corpus), 'corpus': corpus,
            'equivalent': True, 'behavior_sha256': hashlib.sha256(json.dumps(lua['frames'], sort_keys=True).encode()).hexdigest(),
            'host_bounds': host['native_raster'], 'paced_checkpoints': host.get('paced_checkpoints', []),
            'native_seconds': host['native_seconds'], 'visible_frames': host['visible_frames']}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--scenes', nargs='+', choices=driver.SCENES, default=['paused-ms', 'playing'])
    parser.add_argument('--modes', nargs='+', choices=MODES, default=list(MODES))
    parser.add_argument('--frames', type=int, default=128)
    parser.add_argument('--warmup', type=int, default=32)
    parser.add_argument('--rounds', type=int, default=3)
    parser.add_argument('--adapter', choices=('lua', 'host', 'both'), default='both')
    parser.add_argument('--timeout', type=float, default=30)
    parser.add_argument('--native-pair', action='store_true')
    parser.add_argument('--burst-moves', type=int, choices=(1, 4, 16))
    parser.add_argument('--data-entries', type=int, choices=(4, 32, 128))
    parser.add_argument('--environment-scale', action='store_true')
    parser.add_argument('--style-updates', action='store_true')
    parser.add_argument('--host')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args(argv)
    if not 16 <= args.frames <= 512 or not 0 <= args.warmup <= 128 or not 1 <= args.rounds <= 5:
        parser.error('frames 16..512, warmup 0..128, rounds 1..5 required')
    if 'baseline' not in args.modes or not .1 <= args.timeout <= 60:
        parser.error('baseline mode and timeout .1..60 required')
    os.environ['ELXOSC_MPV_BINARY'] = args.host or os.environ.get('ELXOSC_MPV_BINARY') or driver.executable('mpv')
    try:
        variants = {key: value for key, value in {
            'burst_moves': args.burst_moves, 'data_entries': args.data_entries,
            'environment_scale': args.environment_scale or None,
            'style_updates': args.style_updates or None}.items() if value is not None}
        report = run(args.scenes, args.modes, args.frames, args.warmup, args.rounds, args.adapter, args.timeout,
                     args.output.with_suffix('.partial.json'), variants)
        if args.native_pair:
            with tempfile.TemporaryDirectory(prefix='elxosc-hover-native-') as temporary:
                report['native_pairs'] = [native_pair(scene, 16, 0, Path(temporary), args.timeout, paced)
                                          for scene, paced in [('playing', False), ('paused-ms', True)]]
    except Exception as error:
        report = {'schema_version': 1, 'status': 'error', 'error': str(error),
                  'scope': 'failed/partial run; not valid measurement'}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    encoded = json.dumps(report, ensure_ascii=False, indent=2) + '\n'
    if len(encoded.encode()) > driver.MAX_REPORT_BYTES:
        raise ValueError('measurement report exceeds capacity')
    args.output.write_text(encoded, encoding='utf-8')
    print(report['status'])
    return 0 if report['status'] == 'ok' else 1


if __name__ == '__main__':
    raise SystemExit(main())
