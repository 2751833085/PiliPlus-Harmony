#!/usr/bin/env python3
"""Bounded, read-only HDC timing capture; never reports presented FPS.

Only whitelisted QA timing JSON and error-class counters are persisted. No raw
application logs, URLs, message contents or account data are written to disk.
"""
import argparse
from contextlib import closing
import json
import math
import os
from pathlib import Path
import re
import selectors
import subprocess
import time

PROTOCOL = {'PiliPlusFrameTiming': 'summary', 'PiliPlusFrameSamples': 'samples'}
ERRORS = ('RenderFlex', 'Unhandled Exception', 'MissingPluginException',
          'ErrorWidget', '[VideoController] does not support emulator')
MAX_LINE = 65536


def percentile(values, fraction):
    ordered = sorted(values)
    return ordered[int((len(ordered) - 1) * fraction + .5)] if ordered else None


def finite_samples(values):
    if not isinstance(values, list) or not 0 < len(values) <= 20:
        raise ValueError('Invalid timing chunk size')
    if any(isinstance(v, bool) or not isinstance(v, (int, float)) or
           not math.isfinite(v) or v < 0 for v in values):
        raise ValueError('Invalid frame duration')
    return values


def parse_event(line):
    for marker, kind in PROTOCOL.items():
        position = line.find(marker + ' ')
        if position < 0:
            continue
        data, _ = json.JSONDecoder().raw_decode(line[position + len(marker) + 1:])
        if not isinstance(data, dict):
            raise ValueError('Expected object')
        if kind == 'samples':
            build = finite_samples(data.get('build_ms'))
            raster = finite_samples(data.get('raster_ms'))
            if len(build) != len(raster) or not isinstance(data.get('start'), int):
                raise ValueError('Mismatched sample chunks')
        else:
            frames = data.get('frames')
            if isinstance(frames, bool) or not isinstance(frames, int) or not 0 < frames <= 120:
                raise ValueError('Invalid frame count')
        allowed = ('run_id', 'batch_id', 'start', 'build_ms', 'raster_ms') if kind == 'samples' else (
            'run_id', 'batch_id', 'frames', 'sample_chunks', 'reported_refresh_rate_hz',
            'budget_ms', 'build_p50_ms', 'build_p95_ms', 'raster_p50_ms', 'raster_p95_ms',
            'raster_over_90hz_budget', 'raster_over_120hz_budget', 'over_budget')
        data = {key: value for key, value in data.items() if key in allowed}
        if data.get('run_id') is not None and not re.fullmatch(r'[A-Za-z0-9_-]{1,64}', str(data['run_id'])):
            raise ValueError('Invalid run identity')
        return kind, data
    return None


class TimingSession:
    def __init__(self, discard_boundaries=True):
        self.pending = {}
        self.completed = []
        self.invalid_events = 0
        self.duplicates = 0
        self.errors = {key: 0 for key in ERRORS}
        self.discard_boundaries = discard_boundaries
        self._last_scene = None
        self._finished_keys = set()
        self._legacy_id = 0

    def ingest(self, line, scene, elapsed_s):
        for key in ERRORS:
            if key in line:
                self.errors[key] += 1
        try:
            event = parse_event(line)
            if event is None:
                return None
            kind, data = event
            run, batch = data.get('run_id'), data.get('batch_id')
            if kind == 'summary' and batch is None:
                self._legacy_id += 1
                key = ('legacy', self._legacy_id)
            elif not isinstance(run, str) or len(run) > 64 or not isinstance(batch, int):
                raise ValueError('Missing batch identity')
            else:
                key = (run, batch)
            if key in self._finished_keys:
                self.duplicates += 1
                return None
            # Bound malformed/incomplete output as well as completed batches.
            if len(self.pending) >= 10000 and key not in self.pending:
                raise ValueError('Too many incomplete batches')
            record = self.pending.setdefault(key, {'chunks': {}, 'summary': None})
            if kind == 'summary':
                if record['summary'] is not None:
                    self.duplicates += 1
                    return None
                record.update(summary=data, scene=scene, elapsed_s=elapsed_s)
            else:
                start = data['start']
                if not 0 <= start < 120 or start + len(data['build_ms']) > 120:
                    raise ValueError('Sample offset outside batch')
                if start in record['chunks']:
                    self.duplicates += 1
                    return None
                record['chunks'][start] = data
            summary = record['summary']
            if summary is None:
                return None
            expected = summary.get('sample_chunks', 0)
            if expected and (not isinstance(expected, int) or expected != (summary['frames'] + 19) // 20):
                raise ValueError('Invalid number of sample chunks')
            if expected and len(record['chunks']) < expected:
                return None
            if expected:
                build, raster = [], []
                for start, chunk in sorted(record['chunks'].items()):
                    if start != len(build):
                        raise ValueError('Missing or overlapping samples')
                    build += chunk['build_ms']
                    raster += chunk['raster_ms']
                if len(build) != summary['frames']:
                    raise ValueError('Summary/sample count mismatch')
                record.update(build_ms=build, raster_ms=raster)
            boundary = record['scene'] != self._last_scene
            self._last_scene = record['scene']
            record['boundary_discarded'] = boundary and self.discard_boundaries
            self.completed.append(record)
            self.pending.pop(key)
            self._finished_keys.add(key)
            return {'event': kind, 'data': data}
        except (ValueError, TypeError, KeyError, json.JSONDecodeError):
            self.invalid_events += 1
            return None

    def report(self):
        scenes = {}
        for record in self.completed:
            name = record['scene']
            target = scenes.setdefault(name, {'batches': [], 'build': [], 'raster': [],
                'boundary_batches_discarded': 0, 'summary_only_frames': 0})
            if record['boundary_discarded']:
                target['boundary_batches_discarded'] += 1
                continue
            s = record['summary']
            target['batches'].append({key: s.get(key) for key in [
                'run_id', 'batch_id', 'frames', 'build_p50_ms', 'build_p95_ms',
                'raster_p50_ms', 'raster_p95_ms']})
            if 'build_ms' in record:
                target['build'] += record['build_ms']
                target['raster'] += record['raster_ms']
            else:
                target['summary_only_frames'] += s['frames']
        output = {}
        for name, scene in scenes.items():
            build, raster = scene.pop('build'), scene.pop('raster')
            exact = bool(build) and scene['summary_only_frames'] == 0
            output[name] = {**scene, 'raw_frame_samples': len(build),
                'frames_reported': sum(x['frames'] for x in scene['batches']),
                'scene_quantiles_exact': exact,
                'build_p50_ms': percentile(build, .5) if exact else None,
                'build_p95_ms': percentile(build, .95) if exact else None,
                'raster_p50_ms': percentile(raster, .5) if exact else None,
                'raster_p95_ms': percentile(raster, .95) if exact else None,
                'raster_over_16_67_ms': sum(x > 1000 / 60 for x in raster),
                'raster_over_11_11_ms': sum(x > 1000 / 90 for x in raster),
                'raster_over_8_33_ms': sum(x > 1000 / 120 for x in raster)}
        return {'schema': 1, 'measurement_status': 'complete_batches' if self.completed else 'no_complete_batches', 'metric': 'Flutter build/raster work duration; NOT presented FPS',
            'presented_fps': None, 'scenes': output,
            'invalid_events': self.invalid_events, 'duplicate_events': self.duplicates,
            'incomplete_batches': len(self.pending), 'error_class_counts': self.errors,
            'scope': 'Frames in complete timing batches only. Boundary batches are discarded '
                     'because a 120-frame batch can straddle a scene marker. Legacy summary '
                     'percentiles are retained per batch, never averaged into scene quantiles.'}


def read_markers(path, started, elapsed, default):
    scene = default
    if not path or not path.exists():
        return scene
    if path.stat().st_size > 1024 * 1024:
        raise ValueError('Marker file exceeds 1 MiB')
    for line in path.read_text().splitlines():
        try:
            item = json.loads(line)
            when = float(item['host_epoch']) - started
            label = item['scene']
            if 0 <= when <= elapsed and isinstance(label, str) and 0 < len(label) <= 64:
                scene = label
        except (ValueError, TypeError, KeyError):
            pass
    return scene


def log_epoch(line):
    # -v epoch is independent of local timezone and 12/24-hour UI formatting.
    # hilog emits seconds since 1970 with a fractional second prefix.
    match = re.match(r'^\s*(\d{9,12}(?:\.\d{1,9})?)\s+', line)
    return float(match[1]) if match else None


def bounded_lines(command, duration):
    """Terminate only this local HDC log client at the deadline, never the app."""
    process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                               bufsize=0)
    selector = selectors.DefaultSelector()
    selector.register(process.stdout, selectors.EVENT_READ)
    deadline = time.monotonic() + duration
    buffer = b''
    try:
        while time.monotonic() < deadline:
            for key, _ in selector.select(min(.5, max(0, deadline - time.monotonic()))):
                chunk = os.read(key.fd, 16384)
                if not chunk:
                    return
                buffer += chunk
                while b'\n' in buffer:
                    line, buffer = buffer.split(b'\n', 1)
                    if len(line) <= MAX_LINE:
                        yield line.decode('utf-8', errors='replace')
                if len(buffer) > MAX_LINE:
                    buffer = b''
    finally:
        selector.close()
        if process.poll() is None:
            process.terminate()
        try:
            process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=3)
        process.stdout.close()


def save(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    capture = sub.add_parser('capture', help='Read only the selected app PID for a bounded interval')
    capture.add_argument('--hdc', default='hdc')
    capture.add_argument('--target', required=True)
    capture.add_argument('--package', default='com.example.piliplus')
    capture.add_argument('--scene', required=True)
    capture.add_argument('--duration', type=float, default=60)
    capture.add_argument('--max-batches', type=int, default=500)
    capture.add_argument('--markers', type=Path)
    capture.add_argument('--output', type=Path, required=True)
    analyze = sub.add_parser('analyze', help='Analyze recorded whitelisted events or an existing local log')
    analyze.add_argument('--input', type=Path, required=True)
    analyze.add_argument('--scene', default='offline')
    analyze.add_argument('--output', type=Path, required=True)
    analyze.add_argument('--include-boundary', action='store_true')
    marker = sub.add_parser('mark', help='Write a local scene marker; does not contact the device')
    marker.add_argument('--markers', type=Path, required=True)
    marker.add_argument('--scene', required=True)
    args = parser.parse_args()
    if hasattr(args, 'scene') and not 0 < len(args.scene) <= 64:
        parser.error('Scene must contain 1..64 characters')
    if args.command == 'mark':
        args.markers.parent.mkdir(parents=True, exist_ok=True)
        with args.markers.open('a') as stream:
            stream.write(json.dumps({'host_epoch': time.time(), 'scene': args.scene},
                                    ensure_ascii=False) + '\n')
        return
    session = TimingSession(discard_boundaries=not getattr(args, 'include_boundary', False))
    if args.command == 'analyze':
        with args.input.open() as stream:
            for line in stream:
                if len(line) > MAX_LINE:
                    continue
                try:
                    event = json.loads(line)
                    session.ingest(event['line'], event.get('scene', args.scene), event.get('elapsed_s', 0))
                except (ValueError, TypeError, KeyError):
                    session.ingest(line, args.scene, 0)
        save(args.output, session.report())
        print(args.output)
        return
    if not 1 <= args.duration <= 3600 or not 1 <= args.max_batches <= 10000:
        parser.error('Duration must be 1..3600 seconds and batches 1..10000')
    if not re.fullmatch(r'[A-Za-z][A-Za-z0-9_.]{0,127}', args.package):
        parser.error('Package must be a bundle identifier, not a shell command')
    base = [args.hdc, '-t', args.target, 'shell']
    def read(command):
        return subprocess.check_output(base + [command], text=True, timeout=15).strip()
    pid = read('pidof ' + args.package)
    if not re.fullmatch(r'\d+', pid):
        raise SystemExit('Expected one running app PID, got: ' + pid[:80])
    clock_text = read('date +%s')
    if not re.fullmatch(r'\d{9,12}', clock_text):
        raise SystemExit('Cannot establish device epoch time; refusing to mix old logs: ' + clock_text[:80])
    device_epoch = float(clock_text)
    started, monotonic = time.time(), time.monotonic()
    events_path = args.output.with_suffix('.samples.jsonl')
    events_path.parent.mkdir(parents=True, exist_ok=True)
    reason = 'duration_or_log_stream_end'
    try:
        # Line buffering makes complete JSONL records visible while collecting;
        # no fsync or device-side persistence is requested.
        with events_path.open('w', buffering=1) as stream:
            with closing(bounded_lines(base + ['hilog -v epoch -P ' + pid], args.duration)) as lines:
                for line in lines:
                    stamp = log_epoch(line)
                    if stamp is None or stamp < device_epoch:
                        continue
                    elapsed = time.monotonic() - monotonic
                    # Store timing protocol only, stripping all unrelated hilog content.
                    try:
                        event = parse_event(line)
                    except (ValueError, TypeError, KeyError):
                        session.invalid_events += 1
                        continue
                    scene = read_markers(args.markers, started, elapsed, args.scene) if event else args.scene
                    if event:
                        kind, data = event
                        safe_line = ('PiliPlusFrameTiming' if kind == 'summary' else 'PiliPlusFrameSamples') + ' ' + json.dumps(data)
                        stream.write(json.dumps({'elapsed_s': elapsed, 'scene': scene, 'line': safe_line},
                                                ensure_ascii=False) + '\n')
                    session.ingest(line, scene, elapsed)
                    if len(session.completed) >= args.max_batches:
                        reason = 'max_batches'
                        break
    except KeyboardInterrupt:
        # closing() terminates only the HDC log client created by this capture.
        # The app, HDC server, and other captures remain untouched.
        reason = 'operator_stop'
    elapsed = time.monotonic() - monotonic
    if reason not in {'max_batches', 'operator_stop'}:
        reason = 'duration' if elapsed >= args.duration - .05 else 'log_stream_ended_early'
    result = session.report()
    result.update(duration_requested_s=args.duration, duration_elapsed_s=elapsed,
                  stop_reason=reason, pid=int(pid), samples_file=str(events_path),
                  fresh_log_filter='hilog -v epoch and device date +%s; second precision; first batch per scene discarded')
    save(args.output, result)
    print(json.dumps({'output': str(args.output), 'complete_batches': len(session.completed),
                      'incomplete_batches': result['incomplete_batches'], 'metric': result['metric']}))


if __name__ == '__main__':
    main()
