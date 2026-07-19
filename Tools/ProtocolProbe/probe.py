#!/usr/bin/env python3
"""Run the M0 read-only Codex app-server protocol probe."""

from __future__ import annotations

import argparse
import json
import shutil
import sys
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from Tools.ProtocolProbe.normalization import (  # noqa: E402
    contains_sensitive_text,
    normalize_rate_limits,
    normalize_token_usage,
    redact,
)
from Tools.ProtocolProbe.protocol import JsonRpcProcess, ProtocolError  # noqa: E402

READ_ONLY_REQUESTS: tuple[tuple[str, Any, bool], ...] = (
    ("account/read", {"refreshToken": False}, True),
    ("account/rateLimits/read", None, False),
    ("account/usage/read", None, False),
    ("thread/loaded/list", {}, True),
)


def _transport_command(codex: str, transport: str, socket_path: str | None) -> list[str]:
    if transport == "stdio":
        return [codex, "app-server", "--stdio"]
    command = [codex, "app-server", "proxy"]
    if socket_path:
        command.extend(["--sock", socket_path])
    return command


def _write_json(path: Path, payload: Any) -> None:
    sanitized = redact(payload)
    if contains_sensitive_text(sanitized):
        raise RuntimeError("redaction guard rejected output")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(sanitized, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def _fixture_projection(captured: dict[str, Any], notifications: list[dict[str, Any]]) -> dict[str, Any]:
    """Compact high-volume personal metrics while retaining observed wire shape."""

    responses = dict(captured)
    limits = responses.get("account/rateLimits/read")
    if isinstance(limits, dict) and "rateLimitResetCredits" in limits:
        responses["account/rateLimits/read"] = {
            **limits,
            "rateLimitResetCredits": "<redacted-unrelated-account-data>",
        }
    usage = responses.get("account/usage/read")
    if isinstance(usage, dict) and isinstance(usage.get("dailyUsageBuckets"), list):
        buckets = usage["dailyUsageBuckets"]
        responses["account/usage/read"] = {
            **usage,
            "dailyUsageBuckets": buckets[:1],
        }
    loaded = responses.get("thread/loaded/list")
    if isinstance(loaded, dict) and isinstance(loaded.get("data"), list):
        thread_ids = loaded["data"]
        responses["thread/loaded/list"] = {
            **loaded,
            "data": thread_ids[:1],
            "observedThreadCount": len(thread_ids),
        }
    return {"responses": responses, "notifications": notifications[:50]}


def run_probe(args: argparse.Namespace) -> tuple[int, dict[str, Any]]:
    codex = shutil.which(args.codex)
    if codex is None:
        return 2, {"status": "BLOCKED", "error": {"type": "MissingExecutable", "message": "codex CLI not found"}}

    command = _transport_command(codex, args.transport, args.socket)
    captured: dict[str, Any] = {}
    errors: dict[str, dict[str, str]] = {}
    notifications: list[dict[str, Any]] = []
    started_at = datetime.now(UTC).isoformat()

    client = JsonRpcProcess(command, timeout=args.timeout)
    try:
        with client:
            initialize = client.request(
                "initialize",
                {
                    "clientInfo": {
                        "name": "pet-halo-protocol-probe",
                        "title": "Pet Halo M0 Protocol Probe",
                        "version": "0.0.0-m0",
                    },
                    "capabilities": {
                        "experimentalApi": True,
                        "requestAttestation": False,
                    },
                },
            )
            captured["initialize"] = initialize
            client.notify("initialized")

            for method, params, include_params in READ_ONLY_REQUESTS:
                try:
                    captured[method] = client.request(method, params, include_params=include_params)
                except ProtocolError as error:
                    errors[method] = {"type": error.__class__.__name__, "message": str(error)}
            notifications = client.collect_notifications(args.observe_seconds)
            stderr_summary = client.stderr_summary
    except ProtocolError as error:
        report = {
            "status": "BLOCKED",
            "transport": args.transport,
            "startedAt": started_at,
            "error": {"type": error.__class__.__name__, "message": str(error)},
            "stderr": client.stderr_summary,
        }
        return 2, report

    rate_limits = captured.get("account/rateLimits/read")
    normalized_limits = normalize_rate_limits(rate_limits)
    token_events = [
        event for event in notifications if event.get("method") == "thread/tokenUsage/updated"
    ]
    context_updates = [normalize_token_usage(event.get("params")) for event in token_events]
    loaded = captured.get("thread/loaded/list")
    loaded_count = len(loaded.get("data", [])) if isinstance(loaded, dict) and isinstance(loaded.get("data"), list) else None

    successful_methods = [method for method, _, _ in READ_ONLY_REQUESTS if method in captured]
    report = {
        "status": "PASS" if not errors else "PARTIAL",
        "transport": args.transport,
        "startedAt": started_at,
        "completedAt": datetime.now(UTC).isoformat(),
        "handshake": "PASS",
        "successfulMethods": successful_methods,
        "methodErrors": errors,
        "rateLimits": normalized_limits,
        "loadedThreadCount": loaded_count,
        "observedNotificationMethods": sorted(
            {event.get("method") for event in notifications if isinstance(event.get("method"), str)}
        ),
        "tokenUsageEventCount": len(token_events),
        "contextUpdates": context_updates,
        "stderr": stderr_summary,
    }
    projected_fixture = _fixture_projection(captured, notifications)
    fixture = {
        "captureMetadata": {
            "transport": args.transport,
            "capturedAt": report["completedAt"],
            "redaction": "deny-by-default strings and token metrics; high-volume arrays compacted",
        },
        **projected_fixture,
    }
    _write_json(args.output_dir / f"{args.transport}-fixture.json", fixture)
    _write_json(args.output_dir / f"{args.transport}-report.json", report)
    return (0 if not errors else 1), redact(report)


def _parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--transport", choices=("stdio", "proxy"), default="stdio")
    parser.add_argument("--socket", help="Explicit proxy socket path; omitted by default for CLI discovery")
    parser.add_argument("--codex", default="codex", help="Codex CLI executable name or path")
    parser.add_argument("--timeout", type=float, default=8.0)
    parser.add_argument("--observe-seconds", type=float, default=5.0)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args(argv)
    if args.timeout <= 0:
        parser.error("--timeout must be positive")
    if args.observe_seconds < 0:
        parser.error("--observe-seconds must not be negative")
    if args.socket and args.transport != "proxy":
        parser.error("--socket is valid only with --transport proxy")
    return args


def main(argv: list[str] | None = None) -> int:
    args = _parse_args(argv or sys.argv[1:])
    code, report = run_probe(args)
    print(json.dumps(report, indent=2, sort_keys=True))
    return code


if __name__ == "__main__":
    raise SystemExit(main())
