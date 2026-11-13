"""Automated Verification Test Suite for Anti-Spam and Anti-Bot Protection System.

Covers:
1. Self-contained built-in CAPTCHA generation, SVG rendering, TTL, and solution validation.
2. Sliding Window Rate Limiting (50 req/min threshold, 429 challenge response).
3. Access clearance restoration upon solving CAPTCHA (52nd request returns 200 OK).
4. Multi-IP quota isolation (attack from IP A does not degrade access for IP B).
5. Gateway request interception across static web interfaces and API endpoints.

Zero third-party dependencies — pure Python standard library.
"""

import collections
import http.client
from http.client import HTTPResponse
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import io
import json
import os
from pathlib import Path
import sys
import tempfile
import threading
import time
import unittest
from urllib.parse import urlencode

BACKEND_DIR = Path(__file__).resolve().parent
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from lan_gateway import GatewayServer, make_gateway
from security_guard import SlidingWindowRateLimiter, CaptchaChallengeManager


# ---------------------------------------------------------------------------
# Test Helpers: Universal Request Dispatcher (Real Socket + In-Memory Stream)
# ---------------------------------------------------------------------------

class _FakeSocket(io.BytesIO):
    def makefile(self, *args, **kwargs):
        return self


class _MockSocket:
    """Simulates a client socket connection for direct in-process HTTP handler testing."""

    def __init__(self, raw_input: bytes, client_ip: str = '127.0.0.1', server_port: int = 8080):
        self._r = io.BytesIO(raw_input)
        self._w = io.BytesIO()
        self.client_ip = client_ip
        self.server_port = server_port

    def makefile(self, mode, *args, **kwargs):
        if 'r' in mode:
            return self._r
        return self._w

    def sendall(self, data):
        self._w.write(data)

    def close(self):
        pass

    def getsockname(self):
        return ('127.0.0.1', self.server_port)

    def getpeername(self):
        return (self.client_ip, 54321)

    def settimeout(self, _):
        pass


class _MockServer:
    def __init__(self, server_port: int = 8080):
        self.server_port = server_port
        self.tls_context = None


# ---------------------------------------------------------------------------
# Suite 1: CaptchaChallengeManager Component Tests (Tier 1 & Tier 2)
# ---------------------------------------------------------------------------

class TestCaptchaChallengeManager(unittest.TestCase):
    def setUp(self):
        self.manager = CaptchaChallengeManager(challenge_ttl=300.0, max_attempts=3)

    def test_challenge_generation_structure(self):
        """Generates self-contained challenge with valid id, math question, svg, and TTL."""
        ch = self.manager.generate_challenge('192.168.1.10')
        self.assertIn('challenge_id', ch)
        self.assertTrue(len(ch['challenge_id']) >= 16)
        self.assertIn('question', ch)
        self.assertTrue(ch['question'].endswith('= ?'))
        self.assertIn('svg', ch)
        self.assertTrue(ch['svg'].startswith('<svg'))
        self.assertTrue(ch['svg'].strip().endswith('</svg>'))
        self.assertGreater(ch['expires_in'], 0)

    def test_svg_vector_rendering_elements(self):
        """Verifies SVG contains vector graphics: background rect, anti-bot noise lines, dots, and text."""
        ch = self.manager.generate_challenge('192.168.1.11')
        svg = ch['svg']
        self.assertIn('<rect', svg)
        self.assertIn('<line', svg)
        self.assertIn('<circle', svg)
        self.assertIn('<text', svg)
        self.assertIn('viewBox="0 0 240 68"', svg)

    def test_verify_solution_correct_answer(self):
        """Solving with the correct arithmetic answer succeeds."""
        ch = self.manager.generate_challenge('192.168.1.12')
        cid = ch['challenge_id']
        record = self.manager.get_challenge(cid)
        self.assertIsNotNone(record)
        correct_answer = record['answer']

        # Must verify successfully
        result = self.manager.verify_solution('192.168.1.12', cid, correct_answer)
        self.assertTrue(result, "Correct answer must return True")

    def test_verify_solution_single_use_token(self):
        """A solved challenge is immediately purged and cannot be replayed."""
        ch = self.manager.generate_challenge('192.168.1.13')
        cid = ch['challenge_id']
        correct_answer = self.manager.get_challenge(cid)['answer']

        self.assertTrue(self.manager.verify_solution('192.168.1.13', cid, correct_answer))
        # Replay attempt must fail
        self.assertFalse(self.manager.verify_solution('192.168.1.13', cid, correct_answer))

    def test_verify_solution_wrong_answer_decrements_attempts(self):
        """Incorrect answer returns False and decrements attempts left."""
        ch = self.manager.generate_challenge('192.168.1.14')
        cid = ch['challenge_id']

        self.assertFalse(self.manager.verify_solution('192.168.1.14', cid, 'wrong-answer-1'))
        rec = self.manager.get_challenge(cid)
        self.assertIsNotNone(rec)
        self.assertEqual(rec['attempts_left'], 2)

    def test_verify_solution_exhaustion_prunes_challenge(self):
        """Exhausting 3 incorrect attempts permanently purges the challenge."""
        ch = self.manager.generate_challenge('192.168.1.15')
        cid = ch['challenge_id']

        self.assertFalse(self.manager.verify_solution('192.168.1.15', cid, 'wrong-1'))
        self.assertFalse(self.manager.verify_solution('192.168.1.15', cid, 'wrong-2'))
        self.assertFalse(self.manager.verify_solution('192.168.1.15', cid, 'wrong-3'))

        # After 3 failed attempts, record is purged
        self.assertIsNone(self.manager.get_challenge(cid))

    def test_verify_solution_ip_binding_protection(self):
        """Submitting a solution for a challenge from a different IP address is rejected."""
        ch = self.manager.generate_challenge('192.168.1.16')
        cid = ch['challenge_id']
        correct_answer = self.manager.get_challenge(cid)['answer']

        # Attempt solve from attacker IP
        result = self.manager.verify_solution('10.0.0.99', cid, correct_answer)
        self.assertFalse(result, "Cross-IP challenge submission must be rejected")

    def test_verify_solution_expired_challenge(self):
        """Expired challenge cannot be solved."""
        short_ttl_manager = CaptchaChallengeManager(challenge_ttl=0.01)
        ch = short_ttl_manager.generate_challenge('192.168.1.17')
        cid = ch['challenge_id']
        ans = short_ttl_manager.get_challenge(cid)['answer']
        time.sleep(0.05)

        self.assertFalse(short_ttl_manager.verify_solution('192.168.1.17', cid, ans))

    def test_active_challenge_reuse(self):
        """Calling generate_challenge for the same IP while a challenge is active reuses it."""
        ch1 = self.manager.generate_challenge('192.168.1.18')
        ch2 = self.manager.generate_challenge('192.168.1.18')
        self.assertEqual(ch1['challenge_id'], ch2['challenge_id'])


# ---------------------------------------------------------------------------
# Suite 2: SlidingWindowRateLimiter Component Tests (Tier 1 & Tier 2)
# ---------------------------------------------------------------------------

class TestSlidingWindowRateLimiter(unittest.TestCase):
    def setUp(self):
        self.limiter = SlidingWindowRateLimiter(
            max_requests=50,
            window_seconds=60.0,
            clearance_duration=1800.0,
        )

    def test_under_threshold_requests_permitted(self):
        """First 50 requests from an IP within the 60-second window are permitted."""
        client_ip = '192.168.1.20'
        for i in range(50):
            allowed, challenge = self.limiter.check_request(client_ip)
            self.assertTrue(allowed, f"Request {i + 1} should be permitted")
            self.assertIsNone(challenge)

    def test_boundary_51st_request_triggers_rate_limit(self):
        """Exactly request #51 triggers the rate limit and generates a CAPTCHA challenge."""
        client_ip = '192.168.1.21'
        for _ in range(50):
            self.limiter.check_request(client_ip)

        # 51st request
        allowed, challenge = self.limiter.check_request(client_ip)
        self.assertFalse(allowed, "51st request must be blocked")
        self.assertIsNotNone(challenge, "Challenge dictionary must be returned")
        self.assertIn('challenge_id', challenge)
        self.assertIn('svg', challenge)

    def test_consecutive_requests_remain_rate_limited(self):
        """Requests 52 and 53 continue to be blocked while challenged."""
        client_ip = '192.168.1.22'
        for _ in range(50):
            self.limiter.check_request(client_ip)

        allowed51, _ = self.limiter.check_request(client_ip)
        allowed52, ch52 = self.limiter.check_request(client_ip)
        allowed53, ch53 = self.limiter.check_request(client_ip)
        self.assertFalse(allowed51)
        self.assertFalse(allowed52)
        self.assertFalse(allowed53)
        self.assertIsNotNone(ch52)
        self.assertIsNotNone(ch53)

    def test_ip_isolation_quotas(self):
        """Exhausting requests from IP A does not impact IP B."""
        ip_a = '192.168.1.30'
        ip_b = '192.168.1.31'

        # Exhaust IP A
        for _ in range(50):
            self.limiter.check_request(ip_a)
        allowed_a, _ = self.limiter.check_request(ip_a)
        self.assertFalse(allowed_a, "IP A must be rate-limited")

        # IP B starts completely fresh
        allowed_b, challenge_b = self.limiter.check_request(ip_b)
        self.assertTrue(allowed_b, "IP B must be permitted on first request")
        self.assertIsNone(challenge_b)

    def test_verify_captcha_restores_access_and_grants_clearance(self):
        """Solving CAPTCHA resets the request window, grants clearance, and unblocks client."""
        client_ip = '192.168.1.40'
        for _ in range(50):
            self.limiter.check_request(client_ip)

        # 51st request -> blocked
        _, challenge = self.limiter.check_request(client_ip)
        cid = challenge['challenge_id']
        ans = self.limiter.challenge_manager.get_challenge(cid)['answer']

        # Submit correct solution
        verified = self.limiter.verify_captcha(client_ip, cid, ans)
        self.assertTrue(verified)
        self.assertTrue(self.limiter.has_clearance(client_ip))

        # 52nd request must now succeed!
        allowed, ch = self.limiter.check_request(client_ip)
        self.assertTrue(allowed, "Access must be restored after solving CAPTCHA")
        self.assertIsNone(ch)

    def test_sliding_window_expiration(self):
        """Requests older than window_seconds expire and permit new requests."""
        fast_limiter = SlidingWindowRateLimiter(max_requests=2, window_seconds=0.1)
        ip = '192.168.1.50'

        self.assertTrue(fast_limiter.check_request(ip)[0])
        self.assertTrue(fast_limiter.check_request(ip)[0])
        self.assertFalse(fast_limiter.check_request(ip)[0])  # 3rd blocked

        time.sleep(0.15)  # Wait for window to slide
        self.assertTrue(fast_limiter.check_request(ip)[0], "Requests must be allowed after window expires")

    def test_render_challenge_html_output(self):
        """Challenge HTML renderer produces valid self-contained HTML with form, inputs, and SVG."""
        challenge = {
            'challenge_id': 'abc123xyz',
            'question': '12 + 15 = ?',
            'svg': '<svg width="240" height="68"><text>12 + 15 = ?</text></svg>',
        }
        rendered = self.limiter.render_challenge_html(challenge, return_url='/admin')
        self.assertIn('<!DOCTYPE html>', rendered)
        self.assertIn('abc123xyz', rendered)
        self.assertIn('12 + 15 = ?', rendered)
        self.assertIn('/api/captcha/solve', rendered)
        self.assertIn('/admin', rendered)


# ---------------------------------------------------------------------------
# Suite 3: Gateway E2E Rate Limiting & CAPTCHA Integration (Tier 3 & Tier 4)
# ---------------------------------------------------------------------------

class TestGatewayAntiSpamE2E(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.web_root = Path(self.temp_dir.name)
        (self.web_root / 'index.html').write_text('<html><body>Home</body></html>', encoding='utf-8')
        (self.web_root / 'app.js').write_text('console.log("ready");', encoding='utf-8')

        self.rate_limiter = SlidingWindowRateLimiter(max_requests=50, window_seconds=60.0)
        self.handler_cls = make_gateway(
            self.web_root,
            api_port=9999,
            allowed_hosts={'127.0.0.1'},
            rate_limiter=self.rate_limiter,
        )

        self.use_mock_socket = False
        self.server = None
        self.server_port = 8080

        # Try to spin up live GatewayServer on loopback
        try:
            self.server = GatewayServer(('127.0.0.1', 0), self.handler_cls)
            self.server_port = self.server.server_port
            self.server_thread = threading.Thread(target=self.server.serve_forever, daemon=True)
            self.server_thread.start()
            test_conn = http.client.HTTPConnection('127.0.0.1', self.server_port, timeout=1)
            test_conn.connect()
            test_conn.close()
        except (PermissionError, OSError):
            self.use_mock_socket = True
            if self.server:
                try:
                    self.server.shutdown()
                    self.server.server_close()
                except Exception:
                    pass
                self.server = None

    def tearDown(self):
        if self.server:
            try:
                self.server.shutdown()
                self.server.server_close()
            except Exception:
                pass
        self.temp_dir.cleanup()

    def _execute_request(self, method: str, path: str, headers: dict = None, body: bytes = None, client_ip: str = '127.0.0.1'):
        """Executes an HTTP request through the Gateway handler (real socket or in-process stream)."""
        hdrs = {
            'Host': f'127.0.0.1:{self.server_port}',
        }
        if headers:
            hdrs.update(headers)

        if not self.use_mock_socket and client_ip == '127.0.0.1':
            try:
                conn = http.client.HTTPConnection('127.0.0.1', self.server_port, timeout=10)
                conn.request(method, path, body=body, headers=hdrs)
                res = conn.getresponse()
                status = res.status
                headers_dict = dict(res.headers)
                data = res.read()
                conn.close()
                return status, headers_dict, data
            except (PermissionError, OSError):
                self.use_mock_socket = True

        # In-process mock socket execution (identical HTTP pipeline)
        req_lines = [f"{method} {path} HTTP/1.1"]
        for k, v in hdrs.items():
            req_lines.append(f"{k}: {v}")
        if body and 'Content-Length' not in hdrs:
            req_lines.append(f"Content-Length: {len(body)}")
        req_lines.append("\r\n")
        raw_header = "\r\n".join(req_lines).encode('utf-8')
        raw_input = raw_header + (body or b'')

        mock_sock = _MockSocket(raw_input, client_ip=client_ip, server_port=self.server_port)
        mock_server = _MockServer(self.server_port)
        self.handler_cls(mock_sock, (client_ip, 54321), mock_server)

        fake_resp = HTTPResponse(_FakeSocket(mock_sock._w.getvalue()))
        fake_resp.begin()
        return fake_resp.status, dict(fake_resp.headers), fake_resp.read()

    def test_gateway_permits_first_50_requests_with_200_ok(self):
        """Sends 50 requests in rapid succession; all receive HTTP 200 OK."""
        client_ip = '192.168.1.60'
        for i in range(50):
            status, _, body = self._execute_request('GET', '/app.js', client_ip=client_ip)
            self.assertEqual(status, 200, f"Request {i + 1} must return 200 OK")
            self.assertEqual(body, b'console.log("ready");')

    def test_gateway_51st_request_triggers_http_429_json(self):
        """The 51st request triggers HTTP 429 Too Many Requests and JSON CAPTCHA challenge."""
        client_ip = '192.168.1.61'
        for _ in range(50):
            self._execute_request('GET', '/app.js', client_ip=client_ip)

        # 51st request with Accept: application/json
        status, headers, body = self._execute_request(
            'GET', '/app.js',
            headers={'Accept': 'application/json'},
            client_ip=client_ip
        )
        self.assertEqual(status, 429, "51st request must trigger HTTP 429")
        self.assertEqual(headers.get('Retry-After'), '60')

        data = json.loads(body.decode('utf-8'))
        self.assertTrue(data.get('rate_limited'))
        self.assertIn('challenge', data)
        ch = data['challenge']
        self.assertIn('challenge_id', ch)
        self.assertIn('question', ch)
        self.assertIn('svg', ch)

    def test_gateway_browser_html_challenge_page(self):
        """Browser request hitting rate limit receives HTTP 429 HTML challenge page."""
        client_ip = '192.168.1.62'
        for _ in range(50):
            self._execute_request('GET', '/index.html', client_ip=client_ip)

        status, headers, body = self._execute_request(
            'GET', '/index.html',
            headers={'Accept': 'text/html'},
            client_ip=client_ip
        )
        self.assertEqual(status, 429)
        self.assertIn('text/html', headers.get('Content-Type', ''))
        html_str = body.decode('utf-8')
        self.assertIn('Xác thực Người dùng', html_str)
        self.assertIn('/api/captcha/solve', html_str)
        self.assertIn('<svg', html_str)

    def test_gateway_wrong_captcha_solution_rejected(self):
        """Submitting an invalid CAPTCHA answer returns HTTP 400 with error."""
        client_ip = '192.168.1.63'
        for _ in range(50):
            self._execute_request('GET', '/app.js', client_ip=client_ip)

        # Trigger challenge
        _, _, body = self._execute_request('GET', '/app.js', headers={'Accept': 'application/json'}, client_ip=client_ip)
        cid = json.loads(body.decode('utf-8'))['challenge']['challenge_id']

        wrong_payload = json.dumps({'challenge_id': cid, 'answer': 'bad_9999'}).encode('utf-8')
        solve_status, _, solve_body = self._execute_request(
            'POST', '/api/captcha/solve',
            headers={'Content-Type': 'application/json; charset=utf-8'},
            body=wrong_payload,
            client_ip=client_ip,
        )
        self.assertEqual(solve_status, 400)
        res_data = json.loads(solve_body.decode('utf-8'))
        self.assertFalse(res_data['success'])
        self.assertIn('new_challenge', res_data)

    def test_gateway_correct_captcha_solve_restores_52nd_request_access(self):
        """Solving CAPTCHA via /api/captcha/solve restores HTTP 200 OK access on request 52."""
        client_ip = '192.168.1.64'
        for _ in range(50):
            self._execute_request('GET', '/app.js', client_ip=client_ip)

        # Request 51: 429
        _, _, body = self._execute_request('GET', '/app.js', headers={'Accept': 'application/json'}, client_ip=client_ip)
        ch = json.loads(body.decode('utf-8'))['challenge']
        cid = ch['challenge_id']

        # Compute correct arithmetic answer
        q = ch['question'].replace(' = ?', '').split()
        a, op, b = int(q[0]), q[1], int(q[2])
        ans = str(a + b if op == '+' else a - b)

        # Submit solution
        correct_payload = json.dumps({'challenge_id': cid, 'answer': ans}).encode('utf-8')
        solve_status, _, solve_body = self._execute_request(
            'POST', '/api/captcha/solve',
            headers={'Content-Type': 'application/json; charset=utf-8'},
            body=correct_payload,
            client_ip=client_ip,
        )
        self.assertEqual(solve_status, 200)
        self.assertTrue(json.loads(solve_body.decode('utf-8'))['success'])

        # Request 52: Normal 200 OK restored!
        status52, _, body52 = self._execute_request('GET', '/app.js', client_ip=client_ip)
        self.assertEqual(status52, 200, "Normal access must be restored after CAPTCHA clearance")
        self.assertEqual(body52, b'console.log("ready");')

    def test_gateway_form_urlencoded_captcha_submission_redirects(self):
        """Browser HTML form POST with urlencoded data redirects (303) to return_url."""
        client_ip = '192.168.1.65'
        for _ in range(50):
            self._execute_request('GET', '/index.html', client_ip=client_ip)

        _, _, body = self._execute_request('GET', '/index.html', headers={'Accept': 'application/json'}, client_ip=client_ip)
        ch = json.loads(body.decode('utf-8'))['challenge']
        cid = ch['challenge_id']

        q = ch['question'].replace(' = ?', '').split()
        ans = str(int(q[0]) + int(q[2]) if q[1] == '+' else int(q[0]) - int(q[2]))

        form_data = urlencode({'challenge_id': cid, 'answer': ans, 'return_url': '/admin'}).encode('utf-8')
        status, headers, _ = self._execute_request(
            'POST', '/api/captcha/solve',
            headers={'Content-Type': 'application/x-www-form-urlencoded'},
            body=form_data,
            client_ip=client_ip,
        )
        self.assertEqual(status, 303)
        self.assertEqual(headers.get('Location'), '/admin')

    def test_gateway_captcha_new_endpoint(self):
        """GET /api/captcha/new issues a fresh challenge."""
        status, _, body = self._execute_request('GET', '/api/captcha/new', client_ip='192.168.1.70')
        self.assertEqual(status, 200)
        data = json.loads(body.decode('utf-8'))
        self.assertTrue(data['success'])
        self.assertIn('challenge', data)
        self.assertIn('question', data['challenge'])

    def test_gateway_multi_ip_isolation(self):
        """Client IP 1 is blocked at 51 requests, but Client IP 2 can still make requests normally."""
        ip1 = '192.168.1.80'
        ip2 = '192.168.1.81'

        for _ in range(50):
            self._execute_request('GET', '/app.js', client_ip=ip1)

        # IP 1 is rate limited
        status1, _, _ = self._execute_request('GET', '/app.js', client_ip=ip1)
        self.assertEqual(status1, 429)

        # IP 2 connects and receives 200 OK
        status2, _, body2 = self._execute_request('GET', '/app.js', client_ip=ip2)
        self.assertEqual(status2, 200)
        self.assertEqual(body2, b'console.log("ready");')


if __name__ == '__main__':
    unittest.main()
