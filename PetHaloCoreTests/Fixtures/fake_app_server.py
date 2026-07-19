#!/usr/bin/env python3
"""Deterministic test-only JSONL app-server. Never included in Pet Halo.app."""

import json
import os
import sys
import time


SCENARIO = sys.argv[1] if len(sys.argv) > 1 else "valid"
initialized = False
notification_sent = False
usage_request_count = 0


def write(payload: dict, *, partial: bool = False) -> None:
    encoded = json.dumps(payload, separators=(",", ":")) + "\n"
    if partial:
        midpoint = len(encoded) // 2
        sys.stdout.write(encoded[:midpoint])
        sys.stdout.flush()
        sys.stdout.write(encoded[midpoint:])
    else:
        sys.stdout.write(encoded)
    sys.stdout.flush()


def result(request_id: int, value: object) -> None:
    write({"id": request_id, "result": value}, partial=SCENARIO == "partial")


for raw_line in sys.stdin:
    message = json.loads(raw_line)
    method = message.get("method")
    request_id = message.get("id")

    if method == "initialize":
        if SCENARIO == "malformed":
            sys.stdout.write("{bad json\n")
            sys.stdout.flush()
            continue
        result(
            request_id,
            {
                "userAgent": "fake",
                "codexHome": "/redacted",
                "platformFamily": "unix",
                "platformOs": "macos",
            },
        )
        continue

    if method == "initialized":
        initialized = True
        if SCENARIO == "stderr":
            print("synthetic stderr must be discarded", file=sys.stderr, flush=True)
        if SCENARIO == "abrupt":
            os._exit(7)
        continue

    if not initialized:
        write({"id": request_id, "error": {"code": -32002, "message": "not initialized"}})
        continue

    if method == "account/read":
        result(
            request_id,
            {
                "account": None if SCENARIO == "auth-unavailable" else {"identity": "discarded"},
                "requiresOpenaiAuth": SCENARIO == "auth-unavailable",
            },
        )
    elif method == "account/rateLimits/read":
        if SCENARIO == "delayed":
            time.sleep(0.05)
        snapshot = {
            "limitId": "codex",
            "limitName": "General",
            "primary": {"usedPercent": 25, "windowDurationMins": 10080, "resetsAt": None},
            "secondary": None,
        }
        result(
            request_id,
            {
                "rateLimits": snapshot,
                "rateLimitsByLimitId": {"codex": snapshot},
                "rateLimitResetCredits": None,
            },
        )
        if SCENARIO in {"sparse", "burst"} and not notification_sent:
            count = 4 if SCENARIO == "burst" else 1
            for _ in range(count):
                write({"method": "account/rateLimits/updated", "params": {"rateLimits": snapshot}})
            notification_sent = True
    elif method == "account/usage/read":
        usage_request_count += 1
        if SCENARIO == "usage-delayed":
            time.sleep(0.2)
        if SCENARIO == "usage-fails" or (
            SCENARIO == "usage-fails-after-first" and usage_request_count > 1
        ):
            write({"id": request_id, "error": {"code": -32601, "message": "unsupported"}})
        else:
            result(
                request_id,
                {
                    "summary": {
                        "lifetimeTokens": None,
                        "peakDailyTokens": 20,
                        "longestRunningTurnSec": None,
                        "currentStreakDays": 2,
                        "longestStreakDays": 3,
                    },
                    "dailyUsageBuckets": [{"startDate": "2026-07-20", "tokens": 10}],
                },
            )
    else:
        write({"id": request_id, "error": {"code": -32601, "message": "unsupported"}})

if SCENARIO == "nonzero":
    raise SystemExit(9)
