from concurrent.futures import ThreadPoolExecutor
from threading import BoundedSemaphore, Event
from unittest import TestCase
from unittest.mock import patch
from urllib.error import HTTPError

from medgemma import nearby_places


class NearbyPlacesTests(TestCase):
    origin = {'latitude': 10.77, 'longitude': 106.70}
    hospital = ('hospital', (10.78, 106.71), {'name': 'Example hospital'}, '')

    def setUp(self):
        nearby_places.clear_cache()

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

        with patch.dict('os.environ', {'SERPER_API_KEY': '', 'MEDGEMMA_SERPER_API_KEY': ''}), \
                ThreadPoolExecutor(max_workers=4) as pool, \
                patch.object(nearby_places, 'SOURCE_LOOKUPS', pool), \
                patch.object(nearby_places, '_overpass_places', overpass), \
                patch.object(nearby_places, '_photon_places', photon):
            try:
                result = nearby_places.search_nearby(self.origin)
                self.assertEqual(result['places'][0]['name'], 'Example hospital')
                self.assertEqual(result['source'], 'openstreetmap')
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

        with patch.dict('os.environ', {'SERPER_API_KEY': '', 'MEDGEMMA_SERPER_API_KEY': ''}), \
                patch.object(nearby_places, '_overpass_places', overpass), \
                patch.object(nearby_places, '_photon_places', photon):
            result = nearby_places.search_nearby(self.origin)
        self.assertEqual(result['places'][0]['name'], 'Example hospital')

    def test_busy_overpass_still_allows_photon_lookup(self):
        busy = BoundedSemaphore(1)
        busy.acquire()
        with patch.dict('os.environ', {'SERPER_API_KEY': '', 'MEDGEMMA_SERPER_API_KEY': ''}), \
                patch.object(nearby_places, 'OVERPASS_SLOTS', busy), \
                patch.object(nearby_places, '_photon_places', return_value=[self.hospital]):
            result = nearby_places.search_nearby(self.origin)
        self.assertEqual(result['places'][0]['name'], 'Example hospital')

    def test_photon_includes_housenumber_in_address(self):
        features = [{
            'geometry': {'coordinates': [106.6995, 10.7721]},
            'properties': {
                'name': 'Bệnh viện Gia Định 2',
                'housenumber': '125',
                'street': 'Lê Lợi',
                'district': 'Bến Thành',
                'city': 'TP.HCM',
            },
        }]
        with patch.object(nearby_places, '_get_json', return_value={'features': features}):
            places = nearby_places._photon_places((10.77, 106.70), 5)
        self.assertEqual(places[0][3], '125 Lê Lợi, Bến Thành, TP.HCM')

    def test_serper_searches_dedups_caches_and_recomputes_distance(self):
        calls = []

        def fake_serper_post(payload, timeout=8):
            calls.append(payload)
            query = payload['q']
            if query == 'bệnh viện':
                return {'places': [
                    {
                        'placeId': 'p_hosp',
                        'title': 'Bệnh viện A',
                        'address': '10 Lê Lợi, Q1',
                        'latitude': 10.772,
                        'longitude': 106.701,
                        'type': 'Bệnh viện đa khoa',
                        'phoneNumber': '+84 28 3822 1111',
                        'rating': 4.5,
                        'ratingCount': 120,
                        'openingHours': {'Thứ Hai': 'Mở cửa cả ngày'},
                    },
                    {
                        'placeId': 'p_far',
                        'title': 'Bệnh viện Quá Xa',
                        'address': 'Xa lộ',
                        'latitude': 10.90,
                        'longitude': 106.90,
                        'type': 'Bệnh viện',
                    },
                ]}
            if query == 'phòng khám':
                return {'places': [
                    # Duplicate hospital returned under clinic query should stay deduped as hospital.
                    {
                        'placeId': 'p_hosp',
                        'title': 'Bệnh viện A',
                        'address': '10 Lê Lợi, Q1',
                        'latitude': 10.772,
                        'longitude': 106.701,
                        'type': 'Bệnh viện đa khoa',
                    },
                    {
                        'placeId': 'p_clinic',
                        'title': 'Phòng khám B',
                        'address': '20 Hai Bà Trưng, Q1',
                        'latitude': 10.775,
                        'longitude': 106.703,
                        'type': 'Phòng khám',
                    },
                ]}
            return {'places': [
                {
                    'placeId': 'p_pharm',
                    'title': 'Nhà thuốc C',
                    'address': '5 Pasteur, Q1',
                    'latitude': 10.771,
                    'longitude': 106.700,
                    'type': 'Hiệu thuốc',
                    'phoneNumber': '0903 490 579',
                },
            ]}

        with patch.dict('os.environ', {'SERPER_API_KEY': 'test-serper-key'}), \
                patch.object(nearby_places, '_serper_post', side_effect=fake_serper_post):
            first = nearby_places.search_nearby({'latitude': 10.7701, 'longitude': 106.7001, 'radius_km': 5})
            self.assertEqual(len(calls), 3)
            self.assertEqual(first['source'], 'google_maps_serper')
            self.assertFalse(first['cached'])
            names = [item['name'] for item in first['places']]
            self.assertEqual(set(names), {'Bệnh viện A', 'Phòng khám B', 'Nhà thuốc C'})
            hosp = next(item for item in first['places'] if item['place_id'] == 'p_hosp')
            self.assertEqual(hosp['kind'], 'hospital')
            self.assertEqual(hosp['dial_number'], '+842838221111')
            self.assertEqual(hosp['rating'], 4.5)
            self.assertEqual(hosp['hours'], 'Mở cửa cả ngày')

            # Small coordinate jitter within ~30m hits the cache with 0 extra Serper credits.
            second = nearby_places.search_nearby({'latitude': 10.7703, 'longitude': 106.7003, 'radius_km': 5})
            self.assertEqual(len(calls), 3)
            self.assertTrue(second['cached'])
            self.assertEqual(second['source'], 'google_maps_serper')

    def test_serper_geocode_and_google_maps_url_parsing(self):
        with patch.dict('os.environ', {'SERPER_API_KEY': 'test-serper-key'}), \
                patch.object(nearby_places, '_serper_post', side_effect=AssertionError('Should not call Serper')):
            direct = nearby_places.search_nearby({
                'address': 'https://www.google.com/maps/place/Cho+Ben+Thanh/@10.7725,106.6980,17z',
            })
        self.assertEqual(len(direct['locations']), 1)
        self.assertAlmostEqual(direct['locations'][0]['latitude'], 10.7725)
        self.assertAlmostEqual(direct['locations'][0]['longitude'], 106.6980)

        calls = []

        def fake_geo(payload, timeout=8):
            calls.append(payload)
            return {'places': [{
                'title': 'Chợ Bến Thành',
                'address': 'Bến Thành, TP.HCM',
                'latitude': 10.7725,
                'longitude': 106.6980,
            }]}

        with patch.dict('os.environ', {'SERPER_API_KEY': 'test-serper-key'}), \
                patch.object(nearby_places, '_serper_post', side_effect=fake_geo):
            first = nearby_places.search_nearby({'address': 'Chợ Bến Thành, TP.HCM'})
            second = nearby_places.search_nearby({'address': '  chợ bến thành, tp.hcm '})
        self.assertEqual(len(calls), 1)
        self.assertEqual(first['locations'][0]['label'], 'Chợ Bến Thành — Bến Thành, TP.HCM')
        self.assertEqual(first, second)

    def test_serper_failure_falls_back_to_openstreetmap(self):
        def failing_serper(*_, **__):
            raise HTTPError(nearby_places.SERPER_MAPS_URL, 402, 'Payment Required', {}, None)

        with patch.dict('os.environ', {'SERPER_API_KEY': 'test-serper-key'}), \
                patch.object(nearby_places, '_serper_post', side_effect=failing_serper), \
                patch.object(nearby_places, '_overpass_places', return_value=[self.hospital]), \
                patch.object(nearby_places, '_photon_places', return_value=[]):
            result = nearby_places.search_nearby(self.origin)
        self.assertEqual(result['source'], 'openstreetmap')
        self.assertEqual(result['places'][0]['name'], 'Example hospital')
