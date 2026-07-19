from __future__ import annotations

import unittest

from Tools.ProtocolProbe.normalization import (
    contains_sensitive_text,
    normalize_rate_limits,
    normalize_token_usage,
    redact,
    redact_diagnostic_text,
    remaining_percent,
)


def snapshot(primary=None, secondary=None, **extra):
    return {
        "limitId": "codex",
        "primary": primary,
        "secondary": secondary,
        "unknownFutureField": {"safeNumber": 7},
        **extra,
    }


class RateLimitNormalizationTests(unittest.TestCase):
    def test_identifies_five_hour_by_duration_not_slot(self):
        payload = {
            "rateLimits": snapshot(
                secondary={"usedPercent": 25, "windowDurationMins": 300, "resetsAt": 123}
            )
        }
        result = normalize_rate_limits(payload)
        self.assertEqual(result["fiveHour"][0]["sourceSlot"], "secondary")
        self.assertEqual(result["fiveHour"][0]["remainingPercent"], 75.0)

    def test_identifies_week_by_duration_not_slot(self):
        payload = {
            "rateLimits": snapshot(
                primary={"usedPercent": 40, "windowDurationMins": 10080, "resetsAt": 456}
            )
        }
        result = normalize_rate_limits(payload)
        self.assertEqual(result["weekly"][0]["sourceSlot"], "primary")
        self.assertEqual(result["weekly"][0]["remainingPercent"], 60.0)

    def test_used_to_remaining_is_clamped_and_null_safe(self):
        self.assertEqual(remaining_percent(35.5), 64.5)
        self.assertEqual(remaining_percent(-1), 100.0)
        self.assertEqual(remaining_percent(120), 0.0)
        self.assertIsNone(remaining_percent(None))
        self.assertIsNone(remaining_percent("25"))

    def test_missing_bucket_and_null_fields(self):
        result = normalize_rate_limits({"rateLimits": snapshot(primary=None, secondary=None)})
        self.assertEqual(result, {"fiveHour": [], "weekly": [], "unknown": []})
        self.assertEqual(
            normalize_rate_limits(None), {"fiveHour": [], "weekly": [], "unknown": []}
        )

    def test_unknown_fields_and_unknown_duration_are_tolerated(self):
        payload = {
            "rateLimits": snapshot(
                primary={
                    "usedPercent": 5,
                    "windowDurationMins": 60,
                    "resetsAt": None,
                    "future": "ignored",
                },
                future="ignored",
            )
        }
        result = normalize_rate_limits(payload)
        self.assertEqual(len(result["unknown"]), 1)
        self.assertEqual(result["unknown"][0]["windowDurationMins"], 60)

    def test_multi_bucket_view_is_preserved_without_legacy_duplicate(self):
        payload = {
            "rateLimits": snapshot(
                primary={"usedPercent": 99, "windowDurationMins": 300, "resetsAt": 1}
            ),
            "rateLimitsByLimitId": {
                "codex": snapshot(
                    primary={"usedPercent": 10, "windowDurationMins": 300, "resetsAt": 2}
                ),
                "other": {
                    "limitId": None,
                    "primary": {"usedPercent": 20, "windowDurationMins": 10080, "resetsAt": 3},
                    "secondary": None,
                },
            },
        }
        result = normalize_rate_limits(payload)
        self.assertEqual([item["limitId"] for item in result["fiveHour"]], ["codex"])
        self.assertEqual([item["limitId"] for item in result["weekly"]], ["other"])


class TokenUsageNormalizationTests(unittest.TestCase):
    def test_context_remaining(self):
        result = normalize_token_usage(
            {"tokenUsage": {"total": {"totalTokens": 250}, "modelContextWindow": 1000}}
        )
        self.assertEqual(result["remainingPercent"], 75.0)

    def test_missing_context_window_is_unavailable(self):
        result = normalize_token_usage(
            {"tokenUsage": {"total": {"totalTokens": 250}, "modelContextWindow": None}}
        )
        self.assertIsNone(result["remainingPercent"])


class RedactionTests(unittest.TestCase):
    def test_redacts_credentials_identity_content_and_paths(self):
        raw = {
            "email": "person@example.com",
            "accessToken": "secret",
            "threadId": "abc",
            "cwd": "/Users/" + "person/project",
            "message": "private",
            "unknownString": "also private",
            "method": "account/read",
            "tokens": 123456,
            "usedPercent": 20,
        }
        safe = redact(raw)
        self.assertEqual(safe["method"], "account/read")
        self.assertEqual(safe["usedPercent"], 20)
        self.assertEqual(safe["tokens"], "<redacted-sensitive-number>")
        self.assertNotIn("person@example.com", repr(safe))
        self.assertNotIn("/Users/person", repr(safe))
        self.assertFalse(contains_sensitive_text(safe))

    def test_diagnostic_redaction_keeps_error_and_removes_secrets(self):
        safe = redact_diagnostic_text(
            "failed /Users/" + "person/.codex/socket for person@example.com Bearer abc.def"
        )
        self.assertIn("failed", safe)
        self.assertNotIn("/Users/person", safe)
        self.assertNotIn("person@example.com", safe)
        self.assertNotIn("abc.def", safe)


if __name__ == "__main__":
    unittest.main()
