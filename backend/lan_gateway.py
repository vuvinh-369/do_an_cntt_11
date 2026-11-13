"""Same-origin demo web gateway. The model/admin API remains on loopback."""
import http.client
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import ipaddress
import json
import os
from pathlib import Path
import re
import socket
from urllib.parse import parse_qs, unquote, urlsplit

try:
    from security_guard import SlidingWindowRateLimiter
except ImportError:
    from .security_guard import SlidingWindowRateLimiter


def local_ipv4_addresses():
    addresses = {'127.0.0.1'}
    try:
        addresses.update(socket.gethostbyname_ex(socket.gethostname())[2])
    except OSError:
        pass
    return sorted(address for address in addresses
                  if ipaddress.ip_address(address).is_private
                  and not ipaddress.ip_address(address).is_unspecified)


class GatewayServer(ThreadingHTTPServer):
    allow_reuse_address = os.name != 'nt'
    daemon_threads = True
    tls_context = None

    def server_bind(self):
        if os.name == 'nt':
            self.socket.setsockopt(socket.SOL_SOCKET, socket.SO_EXCLUSIVEADDRUSE, 1)
        super().server_bind()

    def get_request(self):
        connection, address = super().get_request()
        if self.tls_context is not None:
            try:
                connection = self.tls_context.wrap_socket(
                    connection, server_side=True, do_handshake_on_connect=False)
            except OSError:
                connection.close()
                raise
        return connection, address


def make_gateway(web_root, api_port, allowed_hosts, rate_limiter=None):
    root = Path(web_root).resolve()
    hosts = frozenset(allowed_hosts) | {'127.0.0.1', 'localhost'}
    if rate_limiter is None:
        rate_limiter = SlidingWindowRateLimiter(max_requests=50, window_seconds=60.0)

    class Handler(SimpleHTTPRequestHandler):
        def __init__(self, *args, **kwargs):
            super().__init__(*args, directory=str(root), **kwargs)

        def log_message(self, *_):
            pass

        def setup(self):
            super().setup()
            self.connection.settimeout(30)

        def end_headers(self):
            self.send_header('X-Content-Type-Options', 'nosniff')
            self.send_header('Referrer-Policy', 'same-origin')
            self.send_header('Cache-Control', 'no-cache')
            super().end_headers()

        def json_error(self, status, message):
            body = json.dumps({'error': message}, ensure_ascii=False).encode('utf-8')
            self.send_response(status)
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            if self.command != 'HEAD':
                self.wfile.write(body)

        def check_request(self):
            try:
                address = ipaddress.ip_address(self.client_address[0])
                scheme = 'https' if self.server.tls_context is not None else 'http'
                authority = urlsplit(scheme + '://' + self.headers.get('Host', ''))
                default_port = 443 if scheme == 'https' else 80
                valid = (address.is_private and authority.hostname in hosts
                         and (authority.port or default_port) == self.server.server_port
                         and not authority.username and not authority.password
                         and not authority.path and not authority.query and not authority.fragment
                         and len(self.headers.get_all('Host', [])) == 1)
                origin = self.headers.get('Origin')
                if origin:
                    valid = valid and origin == scheme + '://' + self.headers['Host']
                valid = valid and self.headers.get('Sec-Fetch-Site') != 'cross-site'
                parsed = urlsplit(self.path)
                valid = valid and not parsed.scheme and not parsed.netloc and self.path.startswith('/')
            except ValueError:
                valid = False
            if not valid:
                self.json_error(403, 'Địa chỉ hoặc nguồn kết nối không được phép.')
            return valid

        def api_method(self, path):
            if path in {'/api/chat', '/api/warmup', '/api/analyze-image', '/api/nearby-places'}:
                return 'POST'
            if path in {'/api/status', '/api/knowledge'} or re.fullmatch(
                    r'/api/(knowledge/[0-9]+|source/[A-Za-z0-9_.-]+)', path):
                return 'GET'
            return None

        def proxy_api(self):
            path = urlsplit(self.path).path
            expected = self.api_method(path)
            if expected is None:
                self.json_error(403, 'API này chỉ dùng trực tiếp trên máy chủ.')
                return
            if self.command != expected:
                self.json_error(405, 'Phương thức không được hỗ trợ.')
                return
            body = None
            if expected == 'POST':
                if self.headers.get('Transfer-Encoding') or len(self.headers.get_all('Content-Length', [])) != 1:
                    self.json_error(400, 'Yêu cầu cần độ dài nội dung hợp lệ.')
                    return
                try:
                    length = int(self.headers.get('Content-Length', '0'))
                except ValueError:
                    length = 0
                maximum = 14 * 1024 * 1024 if path == '/api/analyze-image' else 65536
                if not 0 < length <= maximum:
                    self.json_error(413, 'Nội dung gửi lên quá lớn hoặc trống.')
                    return
                if self.headers.get('Content-Type', '').split(';')[0].strip().lower() != 'application/json':
                    self.json_error(415, 'Hãy gửi dữ liệu dạng JSON.')
                    return
                body = self.rfile.read(length)
                if len(body) != length:
                    self.json_error(400, 'Nội dung gửi lên chưa đầy đủ.')
                    return
            upstream = http.client.HTTPConnection('127.0.0.1', api_port, timeout=300)
            responded = False
            try:
                # Never relay arbitrary destinations, Origin, cookies or admin headers.
                upstream.request(self.command, self.path, body=body,
                                 headers={'Content-Type': 'application/json; charset=utf-8'} if body else {})
                response = upstream.getresponse()
                self.send_response(response.status)
                for name in ('Content-Type', 'Content-Length', 'Content-Disposition'):
                    value = response.getheader(name)
                    if value is not None:
                        self.send_header(name, value)
                self.end_headers()
                responded = True
                while chunk := response.read(65536):
                    self.wfile.write(chunk)
            except (OSError, http.client.HTTPException):
                if not responded:
                    self.json_error(503, 'Chưa kết nối được dịch vụ AI trên máy chủ.')
            finally:
                upstream.close()

        def serve_static(self):
            decoded = unquote(urlsplit(self.path).path)
            if '\\' in decoded or '\x00' in decoded or '..' in Path(decoded).parts:
                self.json_error(404, 'Không tìm thấy tệp.')
                return
            candidate = (root / decoded.lstrip('/')).resolve()
            if not candidate.is_relative_to(root) or any(part.startswith('.') for part in Path(decoded).parts if part != '/'):
                self.json_error(404, 'Không tìm thấy tệp.')
                return
            if candidate.is_file():
                self.path = urlsplit(self.path).path
            elif decoded == '/' or (not candidate.suffix and not candidate.exists()):
                if not (root / 'index.html').resolve().is_relative_to(root):
                    self.json_error(404, 'Không tìm thấy tệp.')
                    return
                self.path = '/index.html'
            else:
                self.json_error(404, 'Không tìm thấy tệp.')
                return
            if self.command == 'HEAD':
                super().do_HEAD()
            else:
                super().do_GET()

        def enforce_rate_limit(self):
            client_ip = self.client_address[0]
            allowed, challenge = rate_limiter.check_request(client_ip)
            if allowed:
                return True

            path = urlsplit(self.path).path
            accept = self.headers.get('Accept', '')
            is_api = path.startswith('/api/') or 'application/json' in accept

            self.send_response(429)
            self.send_header('Retry-After', '60')
            if is_api:
                body = json.dumps({
                    'error': 'Tần suất yêu cầu vượt quá giới hạn cho phép (tối đa 50 yêu cầu/phút). Vui lòng giải CAPTCHA.',
                    'rate_limited': True,
                    'challenge': challenge,
                }, ensure_ascii=False).encode('utf-8')
                self.send_header('Content-Type', 'application/json; charset=utf-8')
                self.send_header('Content-Length', str(len(body)))
                self.end_headers()
                if self.command != 'HEAD':
                    self.wfile.write(body)
            else:
                html_bytes = rate_limiter.render_challenge_html(challenge, return_url=self.path).encode('utf-8')
                self.send_header('Content-Type', 'text/html; charset=utf-8')
                self.send_header('Content-Length', str(len(html_bytes)))
                self.end_headers()
                if self.command != 'HEAD':
                    self.wfile.write(html_bytes)
            return False

        def handle_captcha_solve(self):
            try:
                length = int(self.headers.get('Content-Length', '0'))
            except ValueError:
                length = 0
            if length <= 0 or length > 65536:
                self.json_error(400, 'Dữ liệu yêu cầu không hợp lệ.')
                return
            raw_body = self.rfile.read(length)
            content_type = self.headers.get('Content-Type', '').split(';')[0].strip().lower()
            challenge_id = ''
            answer = ''
            return_url = '/'
            if content_type == 'application/json':
                try:
                    data = json.loads(raw_body.decode('utf-8'))
                    challenge_id = data.get('challenge_id', '')
                    answer = str(data.get('answer', ''))
                    return_url = data.get('return_url', '/')
                except Exception:
                    self.json_error(400, 'Dữ liệu JSON không hợp lệ.')
                    return
            elif content_type == 'application/x-www-form-urlencoded':
                parsed_form = parse_qs(raw_body.decode('utf-8', errors='replace'))
                challenge_id = parsed_form.get('challenge_id', [''])[0]
                answer = parsed_form.get('answer', [''])[0]
                return_url = parsed_form.get('return_url', ['/'])[0]
            else:
                try:
                    data = json.loads(raw_body.decode('utf-8'))
                    challenge_id = data.get('challenge_id', '')
                    answer = str(data.get('answer', ''))
                except Exception:
                    self.json_error(415, 'Định dạng dữ liệu không được hỗ trợ.')
                    return

            client_ip = self.client_address[0]
            success = rate_limiter.verify_captcha(client_ip, challenge_id, answer)
            if success:
                if content_type == 'application/x-www-form-urlencoded':
                    self.send_response(303)
                    self.send_header('Location', return_url if return_url.startswith('/') else '/')
                    self.end_headers()
                    return
                body = json.dumps({
                    'success': True,
                    'message': 'Xác thực thành công. Quyền truy cập đã được khôi phục.',
                }, ensure_ascii=False).encode('utf-8')
                self.send_response(200)
                self.send_header('Content-Type', 'application/json; charset=utf-8')
                self.send_header('Content-Length', str(len(body)))
                self.end_headers()
                self.wfile.write(body)
            else:
                new_challenge = rate_limiter.challenge_manager.generate_challenge(client_ip)
                body = json.dumps({
                    'success': False,
                    'error': 'Mã xác thực không chính xác hoặc đã hết hạn.',
                    'new_challenge': new_challenge,
                }, ensure_ascii=False).encode('utf-8')
                self.send_response(400)
                self.send_header('Content-Type', 'application/json; charset=utf-8')
                self.send_header('Content-Length', str(len(body)))
                self.end_headers()
                self.wfile.write(body)

        def handle_captcha_new(self):
            client_ip = self.client_address[0]
            challenge = rate_limiter.challenge_manager.generate_challenge(client_ip)
            body = json.dumps({
                'success': True,
                'challenge': challenge,
            }, ensure_ascii=False).encode('utf-8')
            self.send_response(200)
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            if self.command != 'HEAD':
                self.wfile.write(body)

        def do_GET(self):
            if not self.check_request():
                return
            path = urlsplit(self.path).path
            if path in {'/api/captcha/new', '/api/captcha-challenge'}:
                self.handle_captcha_new()
                return
            if not self.enforce_rate_limit():
                return
            if path.startswith('/api/'):
                self.proxy_api()
            else:
                self.serve_static()

        def do_HEAD(self):
            if not self.check_request():
                return
            path = urlsplit(self.path).path
            if path in {'/api/captcha/new', '/api/captcha-challenge'}:
                self.send_response(200)
                self.send_header('Content-Type', 'application/json; charset=utf-8')
                self.end_headers()
                return
            if not self.enforce_rate_limit():
                return
            if path.startswith('/api/'):
                self.json_error(405, 'Phương thức không được hỗ trợ.')
            else:
                self.serve_static()

        def do_POST(self):
            if not self.check_request():
                return
            path = urlsplit(self.path).path
            if path in {'/api/captcha/solve', '/api/verify-captcha'}:
                self.handle_captcha_solve()
                return
            if not self.enforce_rate_limit():
                return
            self.proxy_api()

        def do_OPTIONS(self):
            if self.check_request():
                self.json_error(403, 'Mở web từ cùng địa chỉ máy chủ để sử dụng API.')

        def list_directory(self, _):
            self.json_error(404, 'Không tìm thấy tệp.')
            return None

    Handler.rate_limiter = rate_limiter
    return Handler
