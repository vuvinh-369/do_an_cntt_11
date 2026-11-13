"""Anti-Spam and Anti-Bot Security Guard.

Provides:
1. Thread-safe Sliding Window Rate Limiting (default: 50 requests / 60 seconds per IP).
2. Pure Python built-in self-contained CAPTCHA engine (arithmetic challenge + SVG vector rendering).
3. Challenge TTL lifecycle management, IP binding, and clearance token verification.
No external third-party packages or frameworks are used.
"""

import collections
import html
import random
import secrets
import threading
import time
from typing import Dict, Optional, Tuple


class CaptchaChallengeManager:
    """Manages generation, storage, and validation of self-contained CAPTCHA challenges."""

    def __init__(self, challenge_ttl: float = 300.0, max_attempts: int = 3):
        self.challenge_ttl = challenge_ttl
        self.max_attempts = max_attempts
        self._challenges: Dict[str, dict] = {}
        self._ip_to_challenge: Dict[str, str] = {}
        self._lock = threading.Lock()

    def generate_challenge(self, client_ip: str) -> dict:
        """Generates a math arithmetic challenge and pure SVG vector representation."""
        with self._lock:
            # Clean up expired challenges
            self._prune_expired()

            # If client already has an active, valid challenge, return it
            existing_id = self._ip_to_challenge.get(client_ip)
            now = time.time()
            if existing_id and existing_id in self._challenges:
                existing = self._challenges[existing_id]
                if now < existing["expires_at"] and existing["attempts_left"] > 0:
                    return {
                        "challenge_id": existing["id"],
                        "question": existing["question"],
                        "svg": existing["svg"],
                        "expires_in": int(existing["expires_at"] - now),
                    }

            # Generate new arithmetic question: a in [10..50], b in [1..40]
            op = random.choice(["+", "-"])
            if op == "+":
                a = random.randint(10, 50)
                b = random.randint(1, 40)
                answer = a + b
                question = f"{a} + {b} = ?"
            else:
                a = random.randint(20, 60)
                b = random.randint(1, a - 5)
                answer = a - b
                question = f"{a} - {b} = ?"

            challenge_id = secrets.token_hex(16)
            svg_image = self._render_svg(question)
            expires_at = now + self.challenge_ttl

            challenge_data = {
                "id": challenge_id,
                "client_ip": client_ip,
                "question": question,
                "answer": str(answer),
                "svg": svg_image,
                "created_at": now,
                "expires_at": expires_at,
                "attempts_left": self.max_attempts,
            }

            self._challenges[challenge_id] = challenge_data
            self._ip_to_challenge[client_ip] = challenge_id

            return {
                "challenge_id": challenge_id,
                "question": question,
                "svg": svg_image,
                "expires_in": int(self.challenge_ttl),
            }

    def verify_solution(self, client_ip: str, challenge_id: str, answer: str) -> bool:
        """Validates the submitted challenge answer against the stored record."""
        with self._lock:
            self._prune_expired()
            challenge = self._challenges.get(challenge_id)
            if not challenge:
                return False

            # Verify IP binding
            if challenge["client_ip"] != client_ip:
                return False

            now = time.time()
            if now > challenge["expires_at"]:
                self._remove_challenge(challenge_id)
                return False

            challenge["attempts_left"] -= 1

            clean_submitted = str(answer).strip()
            if clean_submitted == challenge["answer"]:
                self._remove_challenge(challenge_id)
                return True

            if challenge["attempts_left"] <= 0:
                self._remove_challenge(challenge_id)

            return False

    def get_challenge(self, challenge_id: str) -> Optional[dict]:
        with self._lock:
            challenge = self._challenges.get(challenge_id)
            if challenge and time.time() < challenge["expires_at"]:
                return challenge
            return None

    def _remove_challenge(self, challenge_id: str):
        challenge = self._challenges.pop(challenge_id, None)
        if challenge:
            ip = challenge.get("client_ip")
            if ip and self._ip_to_challenge.get(ip) == challenge_id:
                self._ip_to_challenge.pop(ip, None)

    def _prune_expired(self):
        now = time.time()
        expired_ids = [
            cid for cid, c in self._challenges.items()
            if now >= c["expires_at"] or c["attempts_left"] <= 0
        ]
        for cid in expired_ids:
            self._remove_challenge(cid)

    def _render_svg(self, text: str) -> str:
        """Renders an arithmetic challenge as a secure, self-contained SVG image with noise."""
        width = 240
        height = 68
        lines = []

        # Background with subtle gradient/pattern
        lines.append(f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">')
        lines.append(f'  <rect width="{width}" height="{height}" fill="#f8fafc" stroke="#cbd5e1" stroke-width="1.5" rx="8"/>')

        # Add random noise lines
        rnd = random.Random()
        for _ in range(5):
            x1 = rnd.randint(5, width - 5)
            y1 = rnd.randint(5, height - 5)
            x2 = rnd.randint(5, width - 5)
            y2 = rnd.randint(5, height - 5)
            color = rnd.choice(["#94a3b8", "#cbd5e1", "#cbd5e1", "#64748b"])
            lines.append(f'  <line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{color}" stroke-width="1.2" stroke-dasharray="3,3"/>')

        # Add random noise dots
        for _ in range(25):
            cx = rnd.randint(5, width - 5)
            cy = rnd.randint(5, height - 5)
            r = rnd.uniform(1.0, 2.2)
            lines.append(f'  <circle cx="{cx:.1f}" cy="{cy:.1f}" r="{r:.1f}" fill="#94a3b8" opacity="0.6"/>')

        # Render challenge characters with slight vertical jitter
        escaped = html.escape(text)
        lines.append(
            f'  <text x="30" y="44" font-family="Consolas, Monaco, monospace" font-size="28" '
            f'font-weight="bold" fill="#0f172a" letter-spacing="3">{escaped}</text>'
        )
        lines.append('</svg>')
        return '\n'.join(lines)


class SlidingWindowRateLimiter:
    """Thread-safe sliding window rate limiter with built-in CAPTCHA verification."""

    def __init__(
        self,
        max_requests: int = 50,
        window_seconds: float = 60.0,
        clearance_duration: float = 1800.0,
        challenge_manager: Optional[CaptchaChallengeManager] = None,
    ):
        self.max_requests = max_requests
        self.window_seconds = window_seconds
        self.clearance_duration = clearance_duration
        self.challenge_manager = challenge_manager or CaptchaChallengeManager()

        self._requests: Dict[str, collections.deque] = collections.defaultdict(collections.deque)
        self._clearance: Dict[str, float] = {}  # ip -> clearance expiration timestamp (monotonic)
        self._lock = threading.Lock()
        self._last_prune: float = 0.0
        self._prune_interval: float = 30.0

    def prune_stale_entries(self, now: Optional[float] = None) -> int:
        """Prunes empty IP deques and expired clearance tokens. Returns count of pruned entries."""
        if now is None:
            now = time.monotonic()
        cutoff = now - self.window_seconds
        stale_ips = []
        for ip, q in self._requests.items():
            while q and q[0] <= cutoff:
                q.popleft()
            if not q:
                stale_ips.append(ip)
        for ip in stale_ips:
            del self._requests[ip]

        expired_clearances = [ip for ip, exp in self._clearance.items() if now >= exp]
        for ip in expired_clearances:
            del self._clearance[ip]

        return len(stale_ips) + len(expired_clearances)

    def check_request(self, client_ip: str) -> Tuple[bool, Optional[dict]]:
        """Checks if a request from client_ip is allowed.

        Returns (True, None) if permitted.
        Returns (False, challenge_dict) if rate limit is exceeded (>50 req/min).
        """
        now = time.monotonic()
        with self._lock:
            # Sweep expired entries periodically or when memory tracking grows
            if now - self._last_prune >= self._prune_interval or len(self._requests) > 1000:
                self.prune_stale_entries(now)
                self._last_prune = now

            # 1. Check if client IP has active clearance token
            clearance_until = self._clearance.get(client_ip, 0.0)
            if now < clearance_until:
                # If IP has active clearance and an empty deque in _requests, prune it
                if client_ip in self._requests and not self._requests[client_ip]:
                    del self._requests[client_ip]
                return True, None
            elif client_ip in self._clearance:
                del self._clearance[client_ip]

            # 2. Sliding window log: remove entries older than (now - window_seconds)
            q = self._requests[client_ip]
            cutoff = now - self.window_seconds
            while q and q[0] <= cutoff:
                q.popleft()

            # 3. Check rate limit
            if len(q) < self.max_requests:
                q.append(now)
                return True, None

            # Rate limit exceeded (>50 requests within 60s)
            # If deque happens to be empty (e.g. max_requests <= 0), prune entry
            if not q and client_ip in self._requests:
                del self._requests[client_ip]

            # Need challenge
            challenge = self.challenge_manager.generate_challenge(client_ip)
            return False, challenge

    def verify_captcha(self, client_ip: str, challenge_id: str, answer: str) -> bool:
        """Verifies solution. If correct, grants access clearance and clears sliding window."""
        valid = self.challenge_manager.verify_solution(client_ip, challenge_id, answer)
        if valid:
            now = time.monotonic()
            with self._lock:
                # Grant clearance
                self._clearance[client_ip] = now + self.clearance_duration
                # Prune request history for this IP to prevent memory growth and immediately restore access
                self._requests.pop(client_ip, None)
            return True
        return False

    def has_clearance(self, client_ip: str) -> bool:
        with self._lock:
            return time.monotonic() < self._clearance.get(client_ip, 0.0)

    def reset_ip(self, client_ip: str):
        with self._lock:
            self._requests.pop(client_ip, None)
            self._clearance.pop(client_ip, None)

    def render_challenge_html(self, challenge: dict, return_url: str = "/") -> str:
        """Renders a self-contained responsive HTML challenge page for web browsers."""
        svg_content = challenge.get("svg", "")
        challenge_id = html.escape(challenge.get("challenge_id", ""))
        question = html.escape(challenge.get("question", ""))
        safe_return = html.escape(return_url)

        return f"""<!DOCTYPE html>
<html lang="vi">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Xác thực bảo mật - Vui lòng xác minh bạn là con người</title>
  <style>
    * {{ box-sizing: border-box; margin: 0; padding: 0; }}
    body {{
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      background-color: #f1f5f9;
      color: #1e293b;
      display: flex;
      min-height: 100vh;
      align-items: center;
      justify-content: center;
      padding: 16px;
    }}
    .card {{
      background: #ffffff;
      border-radius: 12px;
      box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.1), 0 8px 10px -6px rgba(0, 0, 0, 0.1);
      width: 100%;
      max-width: 440px;
      padding: 32px;
      border: 1px solid #e2e8f0;
    }}
    .badge {{
      display: inline-block;
      padding: 4px 10px;
      border-radius: 9999px;
      background-color: #fee2e2;
      color: #991b1b;
      font-size: 12px;
      font-weight: 600;
      margin-bottom: 12px;
    }}
    h1 {{
      font-size: 20px;
      font-weight: 700;
      margin-bottom: 8px;
      color: #0f172a;
    }}
    p.desc {{
      font-size: 14px;
      color: #64748b;
      margin-bottom: 20px;
      line-height: 1.5;
    }}
    .captcha-box {{
      background-color: #f8fafc;
      border: 1px solid #cbd5e1;
      border-radius: 8px;
      padding: 12px;
      display: flex;
      justify-content: center;
      margin-bottom: 16px;
    }}
    .form-group {{
      margin-bottom: 16px;
    }}
    label {{
      display: block;
      font-size: 13px;
      font-weight: 600;
      color: #334155;
      margin-bottom: 6px;
    }}
    input[type="text"] {{
      width: 100%;
      padding: 10px 12px;
      border: 1.5px solid #cbd5e1;
      border-radius: 6px;
      font-size: 16px;
      outline: none;
      transition: border-color 0.2s;
    }}
    input[type="text"]:focus {{
      border-color: #2563eb;
      box-shadow: 0 0 0 3px rgba(37, 99, 235, 0.15);
    }}
    .btn {{
      display: block;
      width: 100%;
      padding: 12px;
      border: none;
      border-radius: 6px;
      background-color: #2563eb;
      color: #ffffff;
      font-size: 15px;
      font-weight: 600;
      cursor: pointer;
      transition: background-color 0.2s;
    }}
    .btn:hover {{
      background-color: #1d4ed8;
    }}
    .error-msg {{
      display: none;
      color: #dc2626;
      font-size: 13px;
      margin-top: 8px;
      font-weight: 500;
    }}
    .footer-note {{
      font-size: 11px;
      color: #94a3b8;
      text-align: center;
      margin-top: 20px;
    }}
  </style>
</head>
<body>
  <div class="card">
    <span class="badge">Hệ thống Bảo vệ Tần suất</span>
    <h1>Xác thực Người dùng</h1>
    <p class="desc">Hệ thống phát hiện hơn 50 yêu cầu/phút từ địa chỉ IP của bạn. Vui lòng giải phép tính dưới đây để khôi phục quyền truy cập.</p>

    <div class="captcha-box">
      {svg_content}
    </div>

    <form id="captchaForm" method="POST" action="/api/captcha/solve">
      <input type="hidden" name="challenge_id" id="challengeId" value="{challenge_id}">
      <input type="hidden" name="return_url" id="returnUrl" value="{safe_return}">

      <div class="form-group">
        <label for="answer">Kết quả phép tính ({question})</label>
        <input type="text" name="answer" id="answerInput" placeholder="Nhập kết quả..." autocomplete="off" autofocus required>
        <div id="errorMsg" class="error-msg"></div>
      </div>

      <button type="submit" class="btn" id="submitBtn">Xác nhận và Tiếp tục</button>
    </form>

    <div class="footer-note">Cơ chế Bảo vệ Tự động Nội bộ — Không dùng dịch vụ bên thứ ba</div>
  </div>

  <script>
    const form = document.getElementById('captchaForm');
    const answerInput = document.getElementById('answerInput');
    const errorMsg = document.getElementById('errorMsg');
    const submitBtn = document.getElementById('submitBtn');

    form.addEventListener('submit', async (e) => {{
      e.preventDefault();
      errorMsg.style.display = 'none';
      submitBtn.disabled = true;
      submitBtn.innerText = 'Đang kiểm tra...';

      const payload = {{
        challenge_id: document.getElementById('challengeId').value,
        answer: answerInput.value.trim(),
        return_url: document.getElementById('returnUrl').value
      }};

      try {{
        const response = await fetch('/api/captcha/solve', {{
          method: 'POST',
          headers: {{
            'Content-Type': 'application/json; charset=utf-8'
          }},
          body: JSON.stringify(payload)
        }});

        const data = await response.json();
        if (response.ok && data.success) {{
          window.location.href = payload.return_url || '/';
        }} else {{
          errorMsg.innerText = data.error || 'Mã xác thực không chính xác. Vui lòng thử lại.';
          errorMsg.style.display = 'block';
          answerInput.value = '';
          answerInput.focus();
          submitBtn.disabled = false;
          submitBtn.innerText = 'Xác nhận và Tiếp tục';
          // Refresh challenge if available
          if (data.new_challenge) {{
            document.getElementById('challengeId').value = data.new_challenge.challenge_id;
            const box = document.querySelector('.captcha-box');
            if (box && data.new_challenge.svg) {{
              box.innerHTML = data.new_challenge.svg;
            }}
          }}
        }}
      }} catch (err) {{
        // Fallback to standard form submit
        form.submit();
      }}
    }});
  </script>
</body>
</html>"""
