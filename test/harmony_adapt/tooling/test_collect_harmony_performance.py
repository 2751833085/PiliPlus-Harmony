import importlib.util
import json
from pathlib import Path
import sys
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

    def test_local_markers_apply_at_the_requested_time(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'markers.jsonl'
            path.write_text('{"host_epoch":110,"scene":"video"}\n')
            self.assertEqual(qa.read_markers(path, 100, 5, 'home'), 'home')
            self.assertEqual(qa.read_markers(path, 100, 12, 'home'), 'video')


if __name__ == '__main__':
    unittest.main()
