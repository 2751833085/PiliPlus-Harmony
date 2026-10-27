import importlib.util
import json
from pathlib import Path
import sys
import subprocess
import signal
import os
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location('harmony_performance', ROOT / 'tool/collect_harmony_performance.py')
qa = importlib.util.module_from_spec(spec)
spec.loader.exec_module(qa)


def sample_batch(batch, build=None, raster=None):
    build = build or list(range(1, 41))
    raster = raster or [x * 2 for x in build]
    summary = {'run_id': 'sample-run', 'batch_id': batch, 'frames': len(build),
               'sample_chunks': (len(build) + 19) // 20,
               'build_p50_ms': qa.percentile(build, .5), 'build_p95_ms': qa.percentile(build, .95),
               'raster_p50_ms': qa.percentile(raster, .5), 'raster_p95_ms': qa.percentile(raster, .95)}
    lines = ['10-27 12:20:10.000 1234 1234 I flutter: PiliPlusFrameTiming ' + json.dumps(summary)]
    for start in range(0, len(build), 20):
        data = {'run_id': 'sample-run', 'batch_id': batch, 'start': start,
                'build_ms': build[start:start + 20], 'raster_ms': raster[start:start + 20]}
        lines.append('10-27 12:20:10.001 1234 1234 I flutter: PiliPlusFrameSamples ' + json.dumps(data))
    return lines


class PerformanceCaptureTest(unittest.TestCase):
    def test_raw_chunks_produce_exact_scene_quantiles_without_fps(self):
        session = qa.TimingSession(discard_boundaries=False)
        for line in sample_batch(1) + sample_batch(2, [100] * 20, [200] * 20):
            session.ingest(line, 'video-tabs', 1)
        scene = session.report()['scenes']['video-tabs']
        self.assertEqual(scene['raw_frame_samples'], 60)
        self.assertEqual(scene['build_p50_ms'], qa.percentile(list(range(1, 41)) + [100] * 20, .5))
        self.assertEqual(scene['raster_p95_ms'], 200)
        self.assertTrue(scene['scene_quantiles_exact'])
        self.assertIsNone(session.report()['presented_fps'])

    def test_chunk_reordering_duplicates_and_missing_parts(self):
        session = qa.TimingSession(discard_boundaries=False)
        summary, first, last = sample_batch(1)
        for line in [last, first, first, summary, summary]:
            session.ingest(line, 'home', 0)
        self.assertEqual(len(session.completed), 1)
        self.assertEqual(session.duplicates, 2)
        self.assertEqual(session.report()['incomplete_batches'], 0)
        session.ingest(sample_batch(2)[0], 'home', 0)
        session.ingest(sample_batch(2)[1], 'home', 0)
        self.assertEqual(session.report()['incomplete_batches'], 1)

    def test_legacy_summary_quantiles_are_not_averaged(self):
        session = qa.TimingSession(discard_boundaries=False)
        session.ingest('PiliPlusFrameTiming {"frames":120,"build_p50_ms":2,"raster_p95_ms":9}', 'legacy', 0)
        scene = session.report()['scenes']['legacy']
        self.assertIsNone(scene['build_p50_ms'])
        self.assertFalse(scene['scene_quantiles_exact'])
        self.assertEqual(scene['summary_only_frames'], 120)
        self.assertEqual(scene['batches'][0]['raster_p95_ms'], 9)

    def test_each_scene_boundary_is_conservatively_discarded_including_return(self):
        session = qa.TimingSession()
        for batch, name in enumerate(['home', 'home', 'video', 'video', 'home', 'home'], 1):
            for line in sample_batch(batch):
                session.ingest(line, name, batch)
        scenes = session.report()['scenes']
        self.assertEqual(scenes['home']['boundary_batches_discarded'], 2)
        self.assertEqual(scenes['home']['raw_frame_samples'], 80)
        self.assertEqual(scenes['video']['raw_frame_samples'], 40)

    def test_invalid_truncated_and_negative_samples_do_not_enter_quantiles(self):
        session = qa.TimingSession()
        for line in ['PiliPlusFrameTiming {',
                     'PiliPlusFrameTiming {"frames":0}',
                     'PiliPlusFrameSamples {"run_id":"x","batch_id":1,"start":0,"build_ms":[-1],"raster_ms":[1]}']:
            session.ingest(line, 'home', 0)
        self.assertEqual(session.invalid_events, 3)
        self.assertFalse(session.completed)

    def test_only_known_timing_fields_survive_and_errors_are_counts(self):
        event = qa.parse_event('private prefix PiliPlusFrameTiming {"frames":1,"account_cookie":"secret"}')
        self.assertNotIn('account_cookie', event[1])
        session = qa.TimingSession()
        session.ingest('Unhandled Exception private unrelated message', 'home', 0)
        report = session.report()
        self.assertEqual(report['error_class_counts']['Unhandled Exception'], 1)
        self.assertNotIn('private unrelated', json.dumps(report))

    def test_bounded_local_process_is_stopped_without_waiting_for_its_exit(self):
        start = time.monotonic()
        lines = list(qa.bounded_lines([sys.executable, '-u', '-c',
            'import time; print("one"); time.sleep(30)'], .2))
        self.assertEqual(lines, ['one'])
        self.assertLess(time.monotonic() - start, 2)

    def test_epoch_timestamp_parsing_is_independent_of_local_clock_display(self):
        self.assertEqual(qa.log_epoch('1793095685.123 1234 1234 I flutter: event'), 1793095685.123)
        self.assertEqual(qa.log_epoch('1793095685.123456789 1234 I flutter: event'),
                         float('1793095685.123456789'))
        self.assertIsNone(qa.log_epoch('10-27 18:08:05.123 1234 I flutter: event'))

    def _write_fake_hdc(self, folder):
        path = Path(folder)
        # Old buffer contents must be ignored even when a blocking stream first
        # dumps them. Realistic epoch prefixes mirror hilog -v epoch output.
        old = '\n'.join(sample_batch(99)).replace('10-27 12:20:10.', '1999999999.')
        fresh = '\n'.join(sample_batch(1) + sample_batch(2))
        fresh = fresh.replace('10-27 12:20:10.', '2000000001.')
        fake = path / 'fake-hdc'
        fake.write_text('#!/usr/bin/env python3\nimport sys,time,os\n'
            'command=sys.argv[-1]\n'
            'if command.startswith("pidof "): print("1234")\n'
            'elif command == "date +%s": print("2000000000")\n'
            'elif command.startswith("hilog "):\n'
            ' if "-x" in command.split(): sys.exit(0)\n'
            ' if "-v epoch" not in command: sys.exit(2)\n'
            ' open(' + repr(str(Path(folder) / 'fake-hdc.pid')) + ',"w").write(str(os.getpid()))\n'
            ' print(' + repr(old + '\n' + fresh) + ',flush=True)\n'
            ' time.sleep(30)\n')
        fake.chmod(0o755)
        return fake

    def _capture_with_fake_hdc(self, folder, duration=1, max_batches=100):
        path = Path(folder)
        fake = self._write_fake_hdc(folder)
        output = path / 'result.json'
        start = time.monotonic()
        result = subprocess.run([sys.executable, '-B', str(ROOT / 'tool/collect_harmony_performance.py'),
            'capture', '--hdc', str(fake), '--target', 'explicit-test-target',
            '--scene', 'test', '--duration', str(duration), '--max-batches', str(max_batches),
            '--output', str(output)], capture_output=True, text=True, timeout=6)
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(output.read_text()), time.monotonic() - start

    def test_capture_follows_until_duration_instead_of_nonblocking_exit(self):
        with tempfile.TemporaryDirectory() as folder:
            report, elapsed = self._capture_with_fake_hdc(folder)
            self.assertGreaterEqual(report['duration_elapsed_s'], .9)
            self.assertLess(elapsed, 4)
            self.assertEqual(report['scenes']['test']['raw_frame_samples'], 40)
            self.assertEqual(report['scenes']['test']['frames_reported'], 40)
            self.assertEqual(report['incomplete_batches'], 0)
            self.assertIn('epoch', report['fresh_log_filter'])

    def test_capture_stops_at_batch_limit_before_duration(self):
        with tempfile.TemporaryDirectory() as folder:
            report, elapsed = self._capture_with_fake_hdc(folder, duration=30, max_batches=2)
            self.assertEqual(report['stop_reason'], 'max_batches')
            self.assertLess(elapsed, 4)

    def test_samples_are_visible_while_running_and_sigint_saves_complete_batches(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder)
            fake = self._write_fake_hdc(folder)
            output = path / 'interrupted.json'
            process = subprocess.Popen([sys.executable, '-B', str(ROOT / 'tool/collect_harmony_performance.py'),
                'capture', '--hdc', str(fake), '--target', 'explicit-test-target',
                '--scene', 'test', '--duration', '30', '--output', str(output)],
                stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            samples = output.with_suffix('.samples.jsonl')
            try:
                deadline = time.monotonic() + 4
                visible = []
                while time.monotonic() < deadline:
                    if samples.exists():
                        visible = samples.read_text().splitlines()
                    if len(visible) >= 6:
                        break
                    time.sleep(.02)
                self.assertGreaterEqual(len(visible), 6, 'JSONL must be flushed before capture ends')
                self.assertIsNone(process.poll(), 'Capture must still be following the log stream')
                hdc_pid = int((path / 'fake-hdc.pid').read_text())
                process.send_signal(signal.SIGINT)
                stdout, stderr = process.communicate(timeout=5)
                self.assertEqual(process.returncode, 0, stderr)
                report = json.loads(output.read_text())
                self.assertEqual(report['stop_reason'], 'operator_stop')
                self.assertEqual(report['scenes']['test']['raw_frame_samples'], 40)
                self.assertEqual(report['incomplete_batches'], 0)
                # Only the locally spawned log client is terminated and reaped.
                with self.assertRaises(ProcessLookupError):
                    os.kill(hdc_pid, 0)
                replay = qa.TimingSession()
                for line in samples.read_text().splitlines():
                    event = json.loads(line)
                    replay.ingest(event['line'], event['scene'], event['elapsed_s'])
                self.assertEqual(replay.report()['scenes']['test']['raw_frame_samples'], 40)
            finally:
                if process.poll() is None:
                    process.terminate()
                    process.communicate(timeout=5)

    def test_local_markers_apply_at_the_requested_time(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'markers.jsonl'
            path.write_text('{"host_epoch":110,"scene":"video"}\n')
            self.assertEqual(qa.read_markers(path, 100, 5, 'home'), 'home')
            self.assertEqual(qa.read_markers(path, 100, 12, 'home'), 'video')


if __name__ == '__main__':
    unittest.main()
