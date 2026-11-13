"""Unit tests for security_guard.py (SlidingWindowRateLimiter and CaptchaChallengeManager)."""

import time
import unittest
from security_guard import SlidingWindowRateLimiter, CaptchaChallengeManager


class TestSecurityGuard(unittest.TestCase):
    def setUp(self):
        self.mgr = CaptchaChallengeManager(challenge_ttl=60.0)
        self.limiter = SlidingWindowRateLimiter(max_requests=50, window_seconds=60.0, challenge_manager=self.mgr)

    def test_challenge_generation_and_validation(self):
        c = self.mgr.generate_challenge("192.168.1.10")
        self.assertIn("challenge_id", c)
        self.assertIn("question", c)
        self.assertIn("svg", c)
        self.assertIn("<svg", c["svg"])

        # Validate with wrong answer
        self.assertFalse(self.mgr.verify_solution("192.168.1.10", c["challenge_id"], "9999"))

        # Determine correct answer
        q = c["question"].replace(" = ?", "")
        parts = q.split()
        a, op, b = int(parts[0]), parts[1], int(parts[2])
        ans = str(a + b if op == "+" else a - b)

        # Validate with right answer
        self.assertTrue(self.mgr.verify_solution("192.168.1.10", c["challenge_id"], ans))

    def test_sliding_window_rate_limiting_threshold_50(self):
        ip = "192.168.1.20"
        # 50 requests should all pass
        for i in range(50):
            allowed, challenge = self.limiter.check_request(ip)
            self.assertTrue(allowed, f"Request {i+1} should be allowed")
            self.assertIsNone(challenge)

        # 51st request should be blocked and return challenge
        allowed, challenge = self.limiter.check_request(ip)
        self.assertFalse(allowed, "51st request must be rate limited")
        self.assertIsNotNone(challenge)
        self.assertIn("challenge_id", challenge)

    def test_clearance_restores_access(self):
        ip = "192.168.1.30"
        for _ in range(50):
            self.limiter.check_request(ip)

        allowed, challenge = self.limiter.check_request(ip)
        self.assertFalse(allowed)

        # Solve challenge
        q = challenge["question"].replace(" = ?", "")
        parts = q.split()
        ans = str(int(parts[0]) + int(parts[2]) if parts[1] == "+" else int(parts[0]) - int(parts[2]))
        solved = self.limiter.verify_captcha(ip, challenge["challenge_id"], ans)
        self.assertTrue(solved)

        # Access immediately restored
        allowed, _ = self.limiter.check_request(ip)
        self.assertTrue(allowed)

    def test_different_ips_isolated(self):
        ip1 = "10.0.0.1"
        ip2 = "10.0.0.2"
        for _ in range(50):
            self.limiter.check_request(ip1)

        allowed1, _ = self.limiter.check_request(ip1)
        self.assertFalse(allowed1)

        allowed2, _ = self.limiter.check_request(ip2)
        self.assertTrue(allowed2)

    def test_pruning_empty_ip_deques(self):
        """Verifies that empty IP deques are removed to prevent unbounded memory growth."""
        ip = "192.168.1.99"
        for _ in range(50):
            self.limiter.check_request(ip)
        _, challenge = self.limiter.check_request(ip)
        self.assertIsNotNone(challenge)

        # Solve challenge
        q = challenge["question"].replace(" = ?", "")
        parts = q.split()
        ans = str(int(parts[0]) + int(parts[2]) if parts[1] == "+" else int(parts[0]) - int(parts[2]))
        self.limiter.verify_captcha(ip, challenge["challenge_id"], ans)

        # After solving, the request deque for this IP must be pruned (not left as an empty deque in _requests)
        self.assertNotIn(ip, self.limiter._requests)

    def test_prune_stale_entries_cleanup(self):
        """Verifies that prune_stale_entries removes stale IP records."""
        fast_limiter = SlidingWindowRateLimiter(max_requests=5, window_seconds=0.05)
        ip1 = "172.16.0.1"
        ip2 = "172.16.0.2"
        fast_limiter.check_request(ip1)
        fast_limiter.check_request(ip2)
        self.assertIn(ip1, fast_limiter._requests)
        self.assertIn(ip2, fast_limiter._requests)

        time.sleep(0.06)
        pruned_count = fast_limiter.prune_stale_entries()
        self.assertEqual(pruned_count, 2)
        self.assertNotIn(ip1, fast_limiter._requests)
        self.assertNotIn(ip2, fast_limiter._requests)


if __name__ == "__main__":
    unittest.main()
