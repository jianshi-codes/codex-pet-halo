"""Normalize generated-protocol payloads without depending on private Codex data."""

from __future__ import annotations

import math
import re
from typing import Any

FIVE_HOURS_MINS = 5 * 60
WEEK_MINS = 7 * 24 * 60

_SENSITIVE_KEY_PARTS = (
    "access_token",
    "accesstoken",
    "authorization",
    "auth_token",
    "authtoken",
    "credential",
    "email",
    "refresh_token",
    "refreshtoken",
    "secret",
    "cookie",
)
_IDENTITY_KEYS = {
    "accountid",
    "conversationid",
    "id",
    "installationid",
    "responseid",
    "threadid",
    "turnid",
    "userid",
}
_CONTENT_KEYS = {
    "content",
    "cwd",
    "message",
    "path",
    "prompt",
    "text",
    "title",
}
_SAFE_STRING_KEYS = {
    "capturedat",
    "completedat",
    "handshake",
    "limitid",
    "limitname",
    "method",
    "observednotificationmethods",
    "ratelimitreachedtype",
    "redaction",
    "sourceslot",
    "startedat",
    "status",
    "stderr",
    "successfulmethods",
    "transport",
    "type",
}
_SENSITIVE_NUMERIC_KEYS = {
    "cachedinputtokens",
    "cachewriteinputtokens",
    "currentstreakdays",
    "inputtokens",
    "lifetimetokens",
    "longestrunningturnsec",
    "longeststreakdays",
    "outputtokens",
    "peakdailytokens",
    "reasoningoutputtokens",
    "tokens",
    "totaltokens",
}
_ABSOLUTE_PATH = re.compile(r"(?:/Users/[^/\s]+|/private/(?:tmp|var)|/tmp)(?:/[^\s]*)?")
_EMAIL = re.compile(r"\b[^\s@]+@[^\s@]+\.[^\s@]+\b")
_BEARER = re.compile(r"(?i)\b(?:bearer|token)\s+[A-Za-z0-9._~+/=-]+")


def _finite_number(value: Any) -> float | None:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return None
    number = float(value)
    return number if math.isfinite(number) else None


def remaining_percent(used_percent: Any) -> float | None:
    """Convert a finite used percentage to a clamped remaining percentage."""

    used = _finite_number(used_percent)
    if used is None:
        return None
    return min(100.0, max(0.0, 100.0 - used))


def _window_kind(duration: Any) -> str | None:
    duration_number = _finite_number(duration)
    if duration_number == FIVE_HOURS_MINS:
        return "fiveHour"
    if duration_number == WEEK_MINS:
        return "weekly"
    return None


def normalize_rate_limits(response: Any) -> dict[str, list[dict[str, Any]]]:
    """Return all semantic windows, preferring the generated multi-bucket view.

    The generated schema calls the two slots primary and secondary, but Pet Halo
    deliberately identifies their meaning only by windowDurationMins.
    """

    normalized: dict[str, list[dict[str, Any]]] = {
        "fiveHour": [],
        "weekly": [],
        "unknown": [],
    }
    if not isinstance(response, dict):
        return normalized

    snapshots: list[tuple[str | None, dict[str, Any]]] = []
    by_id = response.get("rateLimitsByLimitId")
    if isinstance(by_id, dict) and by_id:
        for bucket_id, snapshot in by_id.items():
            if isinstance(snapshot, dict):
                snapshots.append((str(bucket_id), snapshot))
    else:
        legacy = response.get("rateLimits")
        if isinstance(legacy, dict):
            limit_id = legacy.get("limitId")
            snapshots.append((str(limit_id) if limit_id is not None else None, legacy))

    for fallback_id, snapshot in snapshots:
        limit_id = snapshot.get("limitId")
        bucket_id = str(limit_id) if limit_id is not None else fallback_id
        for slot in ("primary", "secondary"):
            window = snapshot.get(slot)
            if not isinstance(window, dict):
                continue
            duration = _finite_number(window.get("windowDurationMins"))
            used = _finite_number(window.get("usedPercent"))
            entry = {
                "limitId": bucket_id,
                "sourceSlot": slot,
                "windowDurationMins": int(duration) if duration is not None else None,
                "usedPercent": used,
                "remainingPercent": remaining_percent(used),
                "resetsAt": window.get("resetsAt")
                if isinstance(window.get("resetsAt"), (int, float))
                and not isinstance(window.get("resetsAt"), bool)
                else None,
            }
            normalized[_window_kind(duration) or "unknown"].append(entry)

    return normalized


def normalize_token_usage(notification_or_usage: Any) -> dict[str, Any]:
    """Calculate context remaining from generated ThreadTokenUsage fields."""

    if not isinstance(notification_or_usage, dict):
        return {"contextWindow": None, "totalTokens": None, "remainingPercent": None}
    usage = notification_or_usage.get("tokenUsage", notification_or_usage)
    if not isinstance(usage, dict):
        return {"contextWindow": None, "totalTokens": None, "remainingPercent": None}
    context_window = _finite_number(usage.get("modelContextWindow"))
    total = usage.get("total")
    total_tokens = _finite_number(total.get("totalTokens")) if isinstance(total, dict) else None
    if context_window is None or context_window <= 0 or total_tokens is None:
        remaining = None
    else:
        remaining = min(100.0, max(0.0, 100.0 * (context_window - total_tokens) / context_window))
    return {
        "contextWindow": int(context_window) if context_window is not None else None,
        "totalTokens": int(total_tokens) if total_tokens is not None else None,
        "remainingPercent": remaining,
    }


def redact(value: Any, key: str | None = None) -> Any:
    """Recursively redact credentials, identity, content, and local paths.

    Unknown string-valued fields are redacted by default. This preserves the
    observed JSON shape while preventing new protocol fields from leaking data.
    """

    normalized_key = re.sub(r"[^a-z0-9]", "", (key or "").lower())
    if any(part.replace("_", "") in normalized_key for part in _SENSITIVE_KEY_PARTS):
        return "<redacted-sensitive>"
    if normalized_key in _IDENTITY_KEYS:
        return "<redacted-id>"
    if normalized_key in _CONTENT_KEYS:
        return "<redacted-content>"
    if normalized_key in _SENSITIVE_NUMERIC_KEYS and isinstance(value, (int, float)):
        return "<redacted-sensitive-number>"
    if isinstance(value, dict):
        return {str(child_key): redact(child_value, str(child_key)) for child_key, child_value in value.items()}
    if isinstance(value, list):
        return [redact(item, key) for item in value]
    if isinstance(value, str):
        if _ABSOLUTE_PATH.search(value):
            return "<redacted-path>"
        if _EMAIL.search(value):
            return "<redacted-email>"
        if normalized_key in _SAFE_STRING_KEYS:
            return value
        return "<redacted-string>"
    return value


def contains_sensitive_text(value: Any) -> bool:
    """Conservative post-redaction guard used before a fixture is written."""

    serialized = repr(value)
    return bool(_EMAIL.search(serialized) or _ABSOLUTE_PATH.search(serialized))


def redact_diagnostic_text(value: str) -> str:
    """Preserve actionable diagnostics while removing common secret/identity forms."""

    safe = _ABSOLUTE_PATH.sub("<redacted-path>", value)
    safe = _EMAIL.sub("<redacted-email>", safe)
    safe = _BEARER.sub("<redacted-sensitive>", safe)
    return safe[:500]
