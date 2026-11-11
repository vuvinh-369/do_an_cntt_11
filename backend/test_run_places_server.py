import http.client
import json
import os
import sys
import threading
import unittest
from pathlib import Path
from unittest import mock

BACKEND_DIR = Path(__file__).resolve().parent
MEDGEMMA_DIR = BACKEND_DIR / 'medgemma'
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))
if str(MEDGEMMA_DIR) not in sys.path:
    sys.path.insert(0, str(MEDGEMMA_DIR))

import nearby_places  # noqa: E402
import run_places_server  # noqa: E402


class _FakeImageService:
    def analyze(self, _payload):
        raise ImportError('missing ultralytics')


class DefaultSerperKeyAndServerTests(unittest.TestCase):
    def _reset_supabase_key_cache(self):
        with nearby_places._SUPABASE_KEY_LOCK:
            nearby_places._SUPABASE_KEY_STATE['expires_at'] = 0.0
            nearby_places._SUPABASE_KEY_STATE['key'] = None
            nearby_places._SUPABASE_KEY_STATE['last_active_key'] = None

    def test_serper_api_key_default_supabase_and_empty_override(self):
        env_without_key = {
            k: v
            for k, v in os.environ.items()
            if k not in {'SERPER_API_KEY', 'MEDGEMMA_SERPER_API_KEY'}
        }
        self._reset_supabase_key_cache()
        with mock.patch.dict(os.environ, env_without_key, clear=True):
            with mock.patch.object(nearby_places, '_fetch_supabase_serper_key', return_value=None):
                self.assertEqual(
                    nearby_places._serper_api_key(),
                    nearby_places.DEFAULT_SERPER_API_KEY,
                )

        self._reset_supabase_key_cache()
        with mock.patch.dict(os.environ, env_without_key, clear=True):
            with mock.patch.object(nearby_places, '_fetch_supabase_serper_key', return_value='supa-key-999'):
                self.assertEqual(nearby_places._serper_api_key(), 'supa-key-999')

        with mock.patch.dict(os.environ, {'SERPER_API_KEY': ''}, clear=True):
            self.assertEqual(nearby_places._serper_api_key(), '')

        with mock.patch.dict(os.environ, {'SERPER_API_KEY': ' custom-123 '}, clear=True):
            self.assertEqual(nearby_places._serper_api_key(), 'custom-123')

    def test_lightweight_server_status_cors_and_nearby(self):
        server = run_places_server.ThreadingHTTPServer(
            ('127.0.0.1', 0),
            run_places_server.make_handler(_FakeImageService()),
        )
        port = server.server_port
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            conn = http.client.HTTPConnection('127.0.0.1', port, timeout=5)
            conn.request('GET', '/api/status')
            resp = conn.getresponse()
            body = json.loads(resp.read().decode('utf-8'))
            self.assertEqual(resp.status, 200)
            self.assertTrue(body['places_ready'])
            self.assertEqual(body['service'], 'places_lightweight')
            conn.close()

            conn = http.client.HTTPConnection('127.0.0.1', port, timeout=5)
            conn.request(
                'OPTIONS',
                '/api/nearby-places',
                headers={
                    'Origin': 'http://localhost:5173',
                    'Access-Control-Request-Method': 'POST',
                    'Access-Control-Request-Headers': 'content-type',
                },
            )
            resp = conn.getresponse()
            resp.read()
            self.assertEqual(resp.status, 204)
            self.assertEqual(
                resp.getheader('Access-Control-Allow-Origin'),
                'http://localhost:5173',
            )
            conn.close()

            conn = http.client.HTTPConnection('127.0.0.1', port, timeout=5)
            conn.request(
                'OPTIONS',
                '/api/nearby-places',
                headers={
                    'Origin': 'https://evil.example',
                    'Access-Control-Request-Method': 'POST',
                },
            )
            resp = conn.getresponse()
            resp.read()
            self.assertEqual(resp.status, 403)
            conn.close()

            conn = http.client.HTTPConnection('127.0.0.1', port, timeout=5)
            conn.request(
                'POST',
                '/api/nearby-places',
                body='{bad-json',
                headers={'Content-Type': 'application/json'},
            )
            resp = conn.getresponse()
            resp.read()
            self.assertEqual(resp.status, 400)
            conn.close()

            sample = {'radius_km': 5, 'source': 'google_maps_serper', 'places': []}
            with mock.patch.object(
                run_places_server,
                'search_nearby',
                return_value=sample,
            ) as mocked:
                conn = http.client.HTTPConnection('127.0.0.1', port, timeout=5)
                conn.request(
                    'POST',
                    '/api/nearby-places',
                    body=json.dumps({'latitude': 10.77, 'longitude': 106.70, 'radius_km': 5}),
                    headers={
                        'Content-Type': 'application/json',
                        'Origin': 'http://127.0.0.1:61000',
                    },
                )
                resp = conn.getresponse()
                data = json.loads(resp.read().decode('utf-8'))
                self.assertEqual(resp.status, 200)
                self.assertEqual(
                    resp.getheader('Access-Control-Allow-Origin'),
                    'http://127.0.0.1:61000',
                )
                self.assertEqual(data, sample)
                mocked.assert_called_once()
                conn.close()

            conn = http.client.HTTPConnection('127.0.0.1', port, timeout=5)
            conn.request(
                'POST',
                '/api/analyze-image',
                body=json.dumps({'image': 'abc'}),
                headers={'Content-Type': 'application/json'},
            )
            resp = conn.getresponse()
            err = json.loads(resp.read().decode('utf-8'))
            self.assertEqual(resp.status, 503)
            self.assertIn('CaiDatNhanh.bat', err['error'])
            conn.close()

            with mock.patch.object(
                run_places_server,
                'refresh_serper_config',
                return_value={'refreshed': True, 'source': 'supabase', 'has_key': True},
            ) as refreshed:
                conn = http.client.HTTPConnection('127.0.0.1', port, timeout=5)
                conn.request(
                    'POST',
                    '/api/serper-refresh',
                    body='{}',
                    headers={
                        'Content-Type': 'application/json',
                        'Origin': 'http://localhost:5173',
                    },
                )
                resp = conn.getresponse()
                refresh_body = json.loads(resp.read().decode('utf-8'))
                self.assertEqual(resp.status, 200)
                self.assertTrue(refresh_body['refreshed'])
                self.assertEqual(refresh_body['source'], 'supabase')
                refreshed.assert_called_once()
                conn.close()

            with mock.patch.object(
                run_places_server,
                'test_serper_api_key',
                return_value={'is_success': True, 'status_code': 200, 'sample_count': 12, 'message': 'OK'},
            ) as tested:
                conn = http.client.HTTPConnection('127.0.0.1', port, timeout=5)
                conn.request(
                    'POST',
                    '/api/serper-test',
                    body=json.dumps({'api_key': 'new-key-abc'}),
                    headers={
                        'Content-Type': 'application/json',
                        'Origin': 'http://localhost:5173',
                    },
                )
                resp = conn.getresponse()
                test_body = json.loads(resp.read().decode('utf-8'))
                self.assertEqual(resp.status, 200)
                self.assertTrue(test_body['is_success'])
                self.assertEqual(test_body['sample_count'], 12)
                tested.assert_called_once_with('new-key-abc')
                conn.close()
        finally:
            server.shutdown()
            server.server_close()


if __name__ == '__main__':
    unittest.main()
