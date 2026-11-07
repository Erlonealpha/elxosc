"""Bounded Windows memory probe using isolated real-host ownership and staging.

Reports Lua heap separately from the owned window process's private/working bytes.
Generated video, no user configuration or private media paths are recorded.
"""

import argparse
import ctypes
import hashlib
import json
import math
import os
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from ctypes import wintypes

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'test' / 'real_host'))
import conftest as host_helpers
from window_input import WindowInput


class MemoryCounters(ctypes.Structure):
    _fields_ = [('cb', wintypes.DWORD), ('PageFaultCount', wintypes.DWORD)] + [
        (name, ctypes.c_size_t) for name in (
            'PeakWorkingSetSize', 'WorkingSetSize', 'QuotaPeakPagedPoolUsage',
            'QuotaPagedPoolUsage', 'QuotaPeakNonPagedPoolUsage', 'QuotaNonPagedPoolUsage',
            'PagefileUsage', 'PeakPagefileUsage', 'PrivateUsage')]


def memory(pid):
    kernel = ctypes.WinDLL('kernel32', use_last_error=True)
    kernel.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
    kernel.OpenProcess.restype = wintypes.HANDLE
    kernel.CloseHandle.argtypes = [wintypes.HANDLE]
    psapi = ctypes.WinDLL('psapi', use_last_error=True)
    psapi.GetProcessMemoryInfo.argtypes = [wintypes.HANDLE, ctypes.POINTER(MemoryCounters), wintypes.DWORD]
    handle = kernel.OpenProcess(0x410, False, pid)
    if not handle:
        raise ctypes.WinError(ctypes.get_last_error())
    try:
        counters = MemoryCounters()
        counters.cb = ctypes.sizeof(counters)
        if not psapi.GetProcessMemoryInfo(handle, ctypes.byref(counters), counters.cb):
            raise ctypes.WinError(ctypes.get_last_error())
        return {'private_bytes': counters.PrivateUsage, 'working_set_bytes': counters.WorkingSetSize}
    finally:
        kernel.CloseHandle(handle)


def git(*args, cwd=ROOT):
    return subprocess.check_output(['git', *args], cwd=cwd, text=True).strip()


def run_case(directory, media, name, seconds, warmup, interval, legacy_ref, collect_each_sample):
    original = host_helpers._stage_elxosc

    def stage(source, destination, include_main=True):
        original(source, destination, include_main)
        entry = destination / 'main.lua'
        content = entry.read_text(encoding='utf-8')
        marker = "require 'elxlib_load' -- sets up elxlibs.*"
        if marker not in content:
            raise RuntimeError('unrecognized entry bootstrap')
        content = content.replace(marker, marker + "\nrequire 'memory_host_probe'")
        content = content.replace('local demo_enabled = true', 'local demo_enabled = false')
        content = content.replace('local debug_enabled = true', 'local debug_enabled = false')
        entry.write_text(content, encoding='utf-8')
        layout = destination / 'main_layout.lua'
        layout_content = layout.read_text(encoding='utf-8')
        layout_marker = "title = 'elxosc',\n        auto_hide_bottom_hover"
        if layout_marker not in layout_content:
            raise RuntimeError('unrecognized Main visibility options')
        layout_content = layout_content.replace(layout_marker,
                                              "title = 'elxosc',\n        auto_hide_enabled = "
                                              + ('false' if 'visible' in name else 'true')
                                              + ",\n        auto_hide_bottom_hover")
        layout.write_text(layout_content, encoding='utf-8')
        shutil.copy2(ROOT / 'tools' / 'memory_host_probe.lua', destination / 'memory_host_probe.lua')
        if name.startswith('legacy_'):
            # One-file causal comparison, not a full historical application.
            old = git('show', f'{legacy_ref}:widget/player_context.lua')
            (destination / 'widget' / 'player_context.lua').write_text(old + '\n', encoding='utf-8')

    host_helpers._stage_elxosc = stage
    try:
        script = ROOT / ('tools/memory_host_probe.lua' if name == 'no_ui' or name.startswith('ass_') else 'main.lua')
        with host_helpers._running_host(directory, (
            f'--script={script}', '--force-window=yes', '--geometry=1280x720',
            '--vo=gpu', '--hwdec=no', '--audio=no', '--msg-level=all=warn',
            '--script-opts=elxosc-memory-hidden=' + ('yes' if 'hidden' in name else 'no'),
            '--script-opts-append=elxosc-memory-no-present=' + ('yes' if name.endswith('no_present') else 'no'),
            '--script-opts-append=elxosc-memory-ass=' + (name.removeprefix('ass_') if name.startswith('ass_') else 'no'),
        )) as (client, config, process, log):
            client.command('loadfile', str(media))
            client.command('set_property', 'pause', False)
            deadline = time.monotonic() + 10
            while client.command('get_property', 'idle-active'):
                if time.monotonic() >= deadline:
                    raise TimeoutError('media failed to load')
                time.sleep(0.05)
            # Allow Define's initialization remount to finish before selecting
            # the visibility controller used by the measured tree.
            time.sleep(1)
            with WindowInput(process, client) as pointer:
                dimensions = client.command('get_property', 'osd-dimensions')
                pointer.move(dimensions['w'] // 2,
                             dimensions['h'] - 45 if 'visible' in name else dimensions['h'] // 2)
                if 'hidden' in name:
                    client.command('script-message', 'elxosc-memory-hide')
                time.sleep(warmup)
                if 'hidden' in name:
                    client.command('script-message', 'elxosc-memory-hide')
                    time.sleep(0.3)
                samples = []

                def sample(force=False):
                    client.command('script-message', 'elxosc-memory-sample', 'gc' if force else 'normal')
                    expected = force
                    started = time.monotonic()
                    while True:
                        try:
                            value = client.command('get_property', 'user-data/elxosc-memory')
                            if value.get('forced_gc') == expected and value.get('time') != (
                                    samples[-1]['time'] if samples else None):
                                break
                        except AssertionError:
                            pass
                        if time.monotonic() - started > 5:
                            raise TimeoutError('Lua sample did not arrive')
                        time.sleep(0.02)
                    value.update(memory(pointer.window_pid))
                    value['elapsed_seconds'] = time.monotonic() - start
                    samples.append(value)
                    print(json.dumps({'case': name, **value}), flush=True)

                start = time.monotonic()
                sample(True)
                for index in range(1, int(seconds / interval) + 1):
                    time.sleep(max(0, start + index * interval - time.monotonic()))
                    sample(collect_each_sample)
                sample(True)
                first, last = samples[0], samples[-1]
                client.command('script-message', 'elxosc-memory-stop-present')
                time.sleep(5)
                sample(True)
                client.command('script-message', 'elxosc-memory-stop-app')
                time.sleep(5)
                sample(True)
                result = {'name': name, 'seconds': seconds, 'warmup_seconds': warmup,
                          'collect_each_sample': collect_each_sample,
                          'cooldown_phases': ['presentation_stopped_5s', 'app_shutdown_5s'],
                          'viewport': dimensions, 'samples': samples,
                          'mpv_version': client.command('get_property', 'mpv-version'),
                          'ffmpeg_version': client.command('get_property', 'ffmpeg-version'),
                          'post_gc_delta': {key: last[key] - first[key] for key in (
                              'lua_kib', 'private_bytes', 'working_set_bytes', 'updates')}}
                if name != 'no_ui' and not name.startswith('ass_'):
                    for value in samples[:-1]:
                        states = value['visibility']
                        if not states or any(state['hidden'] == ('visible' in name) for state in states):
                            raise RuntimeError(f'visibility scenario did not hold: {states}')
                warnings = log.read_text(errors='replace')
                result['log_error_count'] = sum('error' in line.lower() or 'stack traceback' in line.lower()
                                                for line in warnings.splitlines())
                return result
    finally:
        host_helpers._stage_elxosc = original


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--host', default=os.environ.get('ELXOSC_MPV_BINARY'))
    parser.add_argument('--ffmpeg', default=shutil.which('ffmpeg'))
    parser.add_argument('--seconds', type=float, default=60)
    parser.add_argument('--warmup', type=float, default=5)
    parser.add_argument('--interval', type=float, default=5)
    parser.add_argument('--collect-each-sample', action='store_true',
                        help='diagnostic control: full GC at each sample, never changes production GC')
    parser.add_argument('--cases', default='no_ui,legacy_hidden,legacy_visible,current_hidden,current_visible')
    parser.add_argument('--legacy-ref', default='242ad73')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    names = args.cases.split(',')
    if (os.name != 'nt' or not args.ffmpeg or not args.host
            or not all(math.isfinite(value) for value in (args.seconds, args.warmup, args.interval)) or args.seconds <= 0
            or args.warmup < 0 or args.interval <= 0 or args.seconds < args.interval
            or args.interval > 60 or args.warmup > 60 or set(names) - {
                'no_ui', 'legacy_hidden', 'legacy_visible', 'current_hidden', 'current_visible',
                'current_visible_no_present', 'ass_static', 'ass_dynamic'}):
        parser.error('Windows, host, ffmpeg, valid bounded durations and cases required')
    os.environ['ELXOSC_MPV_BINARY'] = args.host
    dependency = ROOT.parent / 'elxlib'
    report = {'schema_version': 1, 'revision': git('rev-parse', 'HEAD'),
              'worktree_status': git('status', '--short'), 'legacy_ref': args.legacy_ref,
              'dependency_revision': git('-c', f'safe.directory={dependency.as_posix()}', 'rev-parse', 'HEAD', cwd=dependency),
              'dependency_modified': bool(git('-c', f'safe.directory={dependency.as_posix()}', 'status', '--porcelain', cwd=dependency)),
              'dependency_class_sha256': hashlib.sha256((dependency / 'elxlibs/std/class.lua').read_bytes()).hexdigest(),
              'probe_sha256': {name: hashlib.sha256((ROOT / 'tools' / name).read_bytes()).hexdigest()
                               for name in ('investigate_memory.py', 'memory_host_probe.lua')},
              'player_context_sha256': hashlib.sha256((ROOT / 'widget/player_context.lua').read_bytes()).hexdigest(),
              'media': 'generated 1280x720 H.264 testsrc2, 60 fps, no audio; software decode, gpu VO',
              'limits': 'short isolated Windows probe, demo/debug off, no external thumbfast; process memory includes player/native; legacy differs only in player_context.lua; hidden controller hide with OS activity suppressed, visible AutoHide disabled in staging',
              'cases': []}
    with tempfile.TemporaryDirectory(prefix='elxosc-memory-') as folder:
        temp = Path(folder)
        media = temp / 'probe.mp4'
        subprocess.run([args.ffmpeg, '-v', 'error', '-f', 'lavfi', '-i', 'testsrc2=size=1280x720:rate=60',
                        '-t', str(args.seconds + args.warmup + 20), '-c:v', 'libx264', '-preset', 'ultrafast',
                        '-crf', '35', '-an', str(media)], check=True)
        for index, name in enumerate(names):
            directory = temp / str(index)
            directory.mkdir()
            report['cases'].append(run_case(directory, media, name, args.seconds, args.warmup,
                                            args.interval, args.legacy_ref, args.collect_each_sample))
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
