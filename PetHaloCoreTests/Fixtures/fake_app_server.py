#!/usr/bin/env python3
"""Deterministic test-only JSONL app-server. Never included in Pet Halo.app."""

import json
import os
import signal
import sys
import time


SCENARIO = sys.argv[1] if len(sys.argv) > 1 else "valid"
OBSERVATION_PATH = sys.argv[2] if len(sys.argv) > 2 else None
initialized = False
notification_sent = False
usage_request_count = 0
rate_request_count = 0
account_request_count = 0


def observe(method: str) -> None:
    if OBSERVATION_PATH is None:
        return
    with open(OBSERVATION_PATH, "a", encoding="utf-8") as stream:
        stream.write(method + "\n")


if SCENARIO == "invalid-delayed-termination":
    def delayed_exit(_signum: int, _frame: object) -> None:
        time.sleep(0.2)
        raise SystemExit(0)

    signal.signal(signal.SIGTERM, delayed_exit)


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
    envelope = {"id": request_id, "result": value}
    if SCENARIO == "unknown-fields":
        envelope["futureEnvelopeField"] = {"ignored": True}
    write(envelope, partial=SCENARIO == "partial")


for raw_line in sys.stdin:
    message = json.loads(raw_line)
    method = message.get("method")
    request_id = message.get("id")
    observe(method)

    if method == "initialize":
        if SCENARIO == "initialize-method-not-found":
            write({"id": request_id, "error": {"code": -32601, "message": "unsupported"}})
            continue
        if SCENARIO == "initialize-internal-error":
            write({"id": request_id, "error": {"code": -32603, "message": "temporary"}})
            continue
        if SCENARIO in {"malformed", "invalid-delayed-termination"}:
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
        account_request_count += 1
        if SCENARIO == "account-method-not-found":
            write({"id": request_id, "error": {"code": -32601, "message": "unsupported"}})
            continue
        if SCENARIO == "account-internal-error":
            write({"id": request_id, "error": {"code": -32603, "message": "temporary"}})
            continue
        authentication_unavailable = SCENARIO in {
            "auth-unavailable",
            "auth-unavailable-rate-must-not-run",
        } or (
            SCENARIO == "account-logout" and account_request_count > 1
        )
        account_response = (
            {
                "account": None if authentication_unavailable else {"identity": "discarded"},
                "requiresOpenaiAuth": authentication_unavailable,
            }
        )
        if SCENARIO == "unknown-fields":
            account_response["futureAccountField"] = ["ignored"]
        result(
            request_id,
            account_response,
        )
    elif method == "account/rateLimits/read":
        rate_request_count += 1
        if SCENARIO == "auth-unavailable-rate-must-not-run":
            write({"id": request_id, "error": {"code": -32603, "message": "must not run"}})
            continue
        if SCENARIO == "rate-method-not-found":
            write({"id": request_id, "error": {"code": -32601, "message": "unsupported"}})
            continue
        if SCENARIO == "rate-internal-error" or (
            SCENARIO == "rate-internal-after-first" and rate_request_count > 1
        ):
            write({"id": request_id, "error": {"code": -32603, "message": "temporary"}})
            continue
        if SCENARIO == "delayed":
            time.sleep(0.05)
        if SCENARIO == "account-update-during-initial" and rate_request_count == 1:
            write({"method": "account/updated", "params": {"account": "must-not-be-used"}})
            time.sleep(0.05)
        if SCENARIO == "rate-notification-during-refresh" and rate_request_count == 2:
            write({"method": "account/rateLimits/updated", "params": {"sparse": True}})
            time.sleep(0.05)
        if SCENARIO == "rate-delayed-after-first" and rate_request_count == 2:
            time.sleep(0.1)
        if SCENARIO == "usage-stale-then-recovers" and rate_request_count == 3:
            write({"method": "account/rateLimits/updated", "params": {"sparse": True}})
            time.sleep(0.05)
        snapshot = {
            "limitId": "codex",
            "limitName": "General",
            "primary": {"usedPercent": 25, "windowDurationMins": 10080, "resetsAt": None},
            "secondary": None,
        }
        if SCENARIO == "rate-invalid-decoding":
            result(request_id, {"rateLimits": "invalid"})
            continue
        if SCENARIO == "rate-missing-weekly":
            snapshot["primary"]["windowDurationMins"] = 300
        if SCENARIO == "unknown-fields":
            snapshot["futureSnapshotField"] = {"ignored": True}
        result(
            request_id,
            {
                "rateLimits": snapshot,
                "rateLimitsByLimitId": {"codex": snapshot},
                "rateLimitResetCredits": None,
                **({"futureRateLimitField": "ignored"} if SCENARIO == "unknown-fields" else {}),
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
        ) or (
            SCENARIO == "usage-stale-then-recovers" and usage_request_count == 2
        ):
            write({"id": request_id, "error": {"code": -32601, "message": "unsupported"}})
        else:
            recovered_usage = SCENARIO == "usage-stale-then-recovers" and usage_request_count > 2
            switched_account = SCENARIO == "account-switch" and usage_request_count > 1
            token_count = 99 if recovered_usage or switched_account else 10
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
                    "dailyUsageBuckets": [{"startDate": "2026-07-20", "tokens": token_count}],
                },
            )
        if SCENARIO in {"account-logout", "account-switch", "account-update-burst"} \
                and usage_request_count == 1:
            write({"method": "account/updated", "params": {"account": "must-not-be-used"}})
            if SCENARIO == "account-update-burst":
                for _ in range(4):
                    write({"method": "account/rateLimits/updated", "params": {"sparse": True}})
        if SCENARIO == "queued-then-abrupt" and usage_request_count == 1:
            write({"method": "account/rateLimits/updated", "params": {"sparse": True}})
            time.sleep(0.05)
            os._exit(8)
    else:
        write({"id": request_id, "error": {"code": -32601, "message": "unsupported"}})

if SCENARIO == "nonzero":
    raise SystemExit(9)
