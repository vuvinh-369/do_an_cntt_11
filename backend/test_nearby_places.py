from concurrent.futures import ThreadPoolExecutor
from threading import BoundedSemaphore, Event
from unittest import TestCase
from unittest.mock import patch

from medgemma import nearby_places


class NearbyPlacesTests(TestCase):
    origin = {'latitude': 10.77, 'longitude': 106.70}
    hospital = ('hospital', (10.78, 106.71), {'name': 'Example hospital'}, '')

    def test_fast_source_does_not_wait_for_slow_source(self):
        started = Event()
        release = Event()
        overpass_finished = Event()

        def overpass(*_):
            started.set()
            release.wait(timeout=5)
            overpass_finished.set()
            return []

        def photon(*_):
            self.assertTrue(started.wait(timeout=2))
            return [self.hospital]

        with ThreadPoolExecutor(max_workers=4) as pool, \
                patch.object(nearby_places, 'SOURCE_LOOKUPS', pool), \
                patch.object(nearby_places, '_overpass_places', overpass), \
                patch.object(nearby_places, '_photon_places', photon):
            try:
                result = nearby_places.search_nearby(self.origin)
                self.assertEqual(result['places'][0]['name'], 'Example hospital')
                self.assertFalse(overpass_finished.is_set())
            finally:
                release.set()

    def test_empty_fast_source_keeps_waiting_for_results(self):
        photon_finished = Event()

        def overpass(*_):
            self.assertTrue(photon_finished.wait(timeout=2))
            return [self.hospital]

        def photon(*_):
            photon_finished.set()
            return []

        with patch.object(nearby_places, '_overpass_places', overpass), \
                patch.object(nearby_places, '_photon_places', photon):
            result = nearby_places.search_nearby(self.origin)
        self.assertEqual(result['places'][0]['name'], 'Example hospital')

    def test_busy_overpass_still_allows_photon_lookup(self):
        busy = BoundedSemaphore(1)
        busy.acquire()
        with patch.object(nearby_places, 'OVERPASS_SLOTS', busy), \
                patch.object(nearby_places, '_photon_places', return_value=[self.hospital]):
            result = nearby_places.search_nearby(self.origin)
        self.assertEqual(result['places'][0]['name'], 'Example hospital')
