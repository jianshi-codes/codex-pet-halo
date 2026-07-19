from __future__ import annotations

import json
import re
import unittest
from pathlib import Path

from Tools.ProtocolProbe.normalization import contains_sensitive_text, normalize_rate_limits


FIXTURES = Path(__file__).parent / "Fixtures" / "CodexProtocol"
SECRET_PATTERN = re.compile(
    r"(?:gh[opusr]_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9_-]{20,}|Bearer\s+[A-Za-z0-9._~+/=-]{20,})"
)


class RealFixtureTests(unittest.TestCase):
    def test_committed_fixtures_are_redacted_and_parseable(self):
        fixtures = sorted(FIXTURES.glob("*.json"))
        self.assertTrue(fixtures, "at least one redacted real fixture is required")
        for path in fixtures:
            text = path.read_text(encoding="utf-8")
            self.assertNotRegex(text, SECRET_PATTERN, path.name)
            self.assertNotIn("/Users/", text, path.name)
            payload = json.loads(text)
            self.assertFalse(contains_sensitive_text(payload), path.name)
            response = payload.get("responses", {}).get("account/rateLimits/read")
            if response is not None:
                normalized = normalize_rate_limits(response)
                self.assertIn("fiveHour", normalized)
                self.assertIn("weekly", normalized)
                self.assertIn("unknown", normalized)


if __name__ == "__main__":
    unittest.main()
