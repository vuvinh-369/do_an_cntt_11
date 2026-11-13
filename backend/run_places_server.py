"""Lightweight local API for Google Maps (Serper.dev) nearby places and optional YOLO scan."""
import argparse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer as BaseThreadingHTTPServer
import json
import os
from pathlib import Path
import socket
import sys
import threading
from urllib.error import URLError
from urllib.request import urlopen
from urllib.parse import urlsplit

BACKEND_DIR = Path(__file__).resolve().parent
MEDGEMMA_DIR = BACKEND_DIR / 'medgemma'
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))
if str(MEDGEMMA_DIR) not in sys.path:
    sys.path.insert(0, str(MEDGEMMA_DIR))

from local_config import load_config
from nearby_places import (
    NearbyPlacesError,
    refresh_serper_config,
    search_nearby,
    test_serper_api_key,
)


class ThreadingHTTPServer(BaseThreadingHTTPServer):
    allow_reuse_address = os.name != 'nt'
    daemon_threads = True

    def server_bind(self):
        if os.name == 'nt':
            self.socket.setsockopt(socket.SOL_SOCKET, socket.SO_EXCLUSIVEADDRUSE, 1)
        super().server_bind()


class _LazyImageService:
    def __init__(self, model_path):
        self.model_path = model_path
        self._service = None
        self._lock = threading.Lock()

    def analyze(self, payload):
        with self._lock:
            if self._service is None:
                from wound_images import WoundImageService
                self._service = WoundImageService(str(self.model_path))
        return self._service.analyze(payload)


def _is_loopback_origin(origin, host_header):
    if not origin:
        return True
    if host_header and origin == f'http://{host_header}':
        return True
    try:
        parsed = urlsplit(origin)
        return (
            parsed.scheme == 'http'
            and parsed.hostname in {'localhost', '127.0.0.1'}
            and parsed.port is not None
            and 1 <= parsed.port <= 65535
            and not parsed.username
            and not parsed.password
            and not parsed.path
            and not parsed.query
            and not parsed.fragment
        )
    except ValueError:
        return False


def make_handler(image_service):
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *_):
            pass

        def _trusted_host(self):
            port = self.server.server_port
            return self.headers.get('Host') in {f'127.0.0.1:{port}', f'localhost:{port}'}

        def end_headers(self):
            origin = self.headers.get('Origin')
            if origin and _is_loopback_origin(origin, self.headers.get('Host')):
                self.send_header('Access-Control-Allow-Origin', origin)
                self.send_header('Vary', 'Origin')
            super().end_headers()

        def _send_json(self, data, status=200):
            raw = json.dumps(data, ensure_ascii=False).encode('utf-8')
            self.send_response(status)
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.send_header('Content-Length', str(len(raw)))
            self.send_header('Cache-Control', 'no-store')
            self.send_header('X-Content-Type-Options', 'nosniff')
            self.end_headers()
            self.wfile.write(raw)

        def do_OPTIONS(self):
            origin = self.headers.get('Origin')
            path = urlsplit(self.path).path
            method = self.headers.get('Access-Control-Request-Method', '').upper()
            expected = (
                'POST'
                if path in {
                    '/api/nearby-places',
                    '/api/analyze-image',
                    '/api/serper-refresh',
                    '/api/serper-test',
                }
                else 'GET'
            )
            requested = {
                x.strip().lower()
                for x in self.headers.get('Access-Control-Request-Headers', '').split(',')
                if x.strip()
            }
            if (
                not self._trusted_host()
                or not origin
                or not _is_loopback_origin(origin, self.headers.get('Host'))
                or path not in {
                    '/api/nearby-places',
                    '/api/analyze-image',
                    '/api/serper-refresh',
                    '/api/serper-test',
                    '/api/status',
                }
                or method != expected
                or not requested <= {'content-type'}
            ):
                self._send_json({'error': 'Nguồn kết nối không được phép.'}, 403)
                return
            self.send_response(204)
            self.send_header('Access-Control-Allow-Methods', expected)
            self.send_header('Access-Control-Allow-Headers', 'Content-Type')
            self.send_header('Access-Control-Max-Age', '600')
            self.end_headers()

        def do_GET(self):
            if not self._trusted_host() or not _is_loopback_origin(self.headers.get('Origin'), self.headers.get('Host')):
                self._send_json({'error': 'Địa chỉ hoặc nguồn kết nối không được phép.'}, 403)
                return
            if urlsplit(self.path).path == '/api/status':
                self._send_json({
                    'service': 'places_lightweight',
                    'places_ready': True,
                    'model_state': 'not_loaded',
                })
                return
            self._send_json({'error': 'Không tìm thấy.'}, 404)

        def do_POST(self):
            if not self._trusted_host() or not _is_loopback_origin(self.headers.get('Origin'), self.headers.get('Host')):
                self._send_json({'error': 'Địa chỉ hoặc nguồn kết nối không được phép.'}, 403)
                return
            path = urlsplit(self.path).path
            if path not in {
                '/api/nearby-places',
                '/api/analyze-image',
                '/api/serper-refresh',
                '/api/serper-test',
            }:
                self._send_json({'error': 'Không tìm thấy.'}, 404)
                return
            try:
                length = int(self.headers.get('Content-Length', '0'))
            except ValueError:
                length = 0
            limit = 14 * 1024 * 1024 if path == '/api/analyze-image' else 65536
            if not 0 < length <= limit:
                self._send_json({'error': 'Yêu cầu quá lớn hoặc không có nội dung.'}, 413)
                return
            try:
                payload = json.loads(self.rfile.read(length))
            except (ValueError, UnicodeError):
                self._send_json({'error': 'JSON không hợp lệ.'}, 400)
                return
            if not isinstance(payload, dict):
                self._send_json({'error': 'Nội dung phải là một đối tượng JSON.'}, 400)
                return

            if path == '/api/serper-refresh':
                self._send_json(refresh_serper_config())
                return

            if path == '/api/serper-test':
                self._send_json(test_serper_api_key(payload.get('api_key', '')))
                return

            if path == '/api/nearby-places':
                try:
                    self._send_json(search_nearby(payload))
                except NearbyPlacesError as exc:
                    self._send_json({'error': exc.message if hasattr(exc, 'message') else str(exc)}, exc.status)
                except Exception:
                    self._send_json({'error': 'Không tra cứu được cơ sở y tế. Hãy thử lại.'}, 500)
                return

            try:
                self._send_json(image_service.analyze(payload))
            except ImportError:
                self._send_json(
                    {'error': 'Thiếu thư viện ultralytics/pillow. Chạy CaiDatNhanh.bat để cài đặt.'},
                    503,
                )
            except Exception as exc:
                status = getattr(exc, 'status', 500)
                self._send_json({'error': str(exc)}, status if isinstance(status, int) else 500)

    return Handler


def _server_already_alive(port):
    try:
        with urlopen(f'http://127.0.0.1:{port}/api/status', timeout=1.0) as response:
            return response.status == 200
    except (OSError, URLError):
        return False


def main():
    load_config()
    parser = argparse.ArgumentParser(description='Lightweight API for nearby places & YOLO.')
    parser.add_argument('--port', type=int, default=8765)
    args = parser.parse_args()

    model_path = BACKEND_DIR.parent / 'lib' / 'AI_Model' / 'best.pt'
    image_service = _LazyImageService(model_path)
    try:
        server = ThreadingHTTPServer(('127.0.0.1', args.port), make_handler(image_service))
    except OSError:
        if _server_already_alive(args.port):
            print(f'API cong {args.port} da hoat dong san sang.', flush=True)
            return
        raise

    print(f'Google Maps (Serper.dev) & YOLO API dang chay tai http://127.0.0.1:{args.port}', flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == '__main__':
    main()
