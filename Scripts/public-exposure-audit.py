#!/usr/bin/env python3
"""Scan every reachable Git blob for material unsafe for public exposure."""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from collections.abc import Iterator
from dataclasses import dataclass
from pathlib import Path


SYNTHETIC_FIXTURE_PATH = "Tests/test_normalization.py"
SYNTHETIC_EMAIL = b"person" + b"@" + b"example.com"
EMAIL_PATTERN = re.compile(rb"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}")
ACCOUNT_ID_PATTERN = re.compile(
    rb'(?i)["\'](?:accountId|chatgptAccountId|account_id)["\']\s*:\s*'
    rb'["\'](?!<redacted)[A-Za-z0-9._-]{8,}["\']'
)

CONTENT_PATTERNS = (
    (
        "user-specific absolute path",
        re.compile(rb"/Users/[A-Za-z0-9._-]+/"),
    ),
    (
        "authorization header",
        re.compile(
            rb"(?i)(?:Authorization):\s*(?:Basic|Bearer)\s+[A-Za-z0-9._~+/=-]{12,}"
        ),
    ),
    (
        "access token",
        re.compile(
            rb"(?:"
            + b"gh"
            + rb"[opusr]_[A-Za-z0-9]{20,}|"
            + b"github_pat_"
            + rb"[A-Za-z0-9_]{20,}|"
            + b"sk-"
            + rb"[A-Za-z0-9_-]{20,}|"
            + b"xox"
            + rb"[baprs]-[A-Za-z0-9-]{20,}|AKIA[A-Z0-9]{16})"
        ),
    ),
    (
        "private key or certificate",
        re.compile(
            b"-----BEGIN "
            + rb"(?:(?:RSA|EC|DSA|OPENSSH|ENCRYPTED) )?PRIVATE KEY-----|"
            + b"-----BEGIN "
            + b"CERTIFICATE-----"
        ),
    ),
    (
        "committed release credential",
        re.compile(
            rb"(?m)(?:DEVELOPER_ID_P12_BASE64|DEVELOPER_ID_P12_PASSWORD|"
            rb"APPLE_NOTARY_KEY_BASE64|APPLE_NOTARY_KEY_ID|"
            rb"APPLE_NOTARY_ISSUER_ID|RELEASE_KEYCHAIN_PASSWORD)\s*[:=]\s*"
            rb"[\"\']?(?!\$|\$\{\{|<)[A-Za-z0-9+/=._-]{8,}"
        ),
    ),
)

SENSITIVE_SUFFIXES = {
    ".cer",
    ".crt",
    ".der",
    ".key",
    ".mobileprovision",
    ".p12",
    ".pem",
    ".pfx",
    ".provisionprofile",
}
ARCHIVE_SUFFIXES = {
    ".7z",
    ".bz2",
    ".dmg",
    ".gz",
    ".pkg",
    ".rar",
    ".tar",
    ".tgz",
    ".txz",
    ".xz",
    ".zip",
}
ARCHIVE_MAGICS = (
    b"PK\x03\x04",
    b"PK\x05\x06",
    b"PK\x07\x08",
    b"\x1f\x8b",
    b"BZh",
    b"\xfd7zXZ\x00",
    b"7z\xbc\xaf\x27\x1c",
    b"Rar!\x1a\x07",
    b"xar!",
)


@dataclass(frozen=True, order=True)
class Finding:
    category: str
    object_id: str
    path: str


def git(repository: Path, *arguments: str, input_bytes: bytes | None = None) -> bytes:
    return subprocess.run(
        ["git", "-C", str(repository), *arguments],
        input=input_bytes,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=True,
    ).stdout


def reachable_objects(repository: Path) -> tuple[list[str], dict[str, set[str]]]:
    object_ids: list[str] = []
    paths: dict[str, set[str]] = {}
    seen: set[str] = set()
    for raw_line in git(repository, "rev-list", "--objects", "--all").splitlines():
        object_id_bytes, separator, path_bytes = raw_line.partition(b" ")
        object_id = object_id_bytes.decode("ascii")
        if object_id not in seen:
            object_ids.append(object_id)
            seen.add(object_id)
        if separator:
            paths.setdefault(object_id, set()).add(
                path_bytes.decode("utf-8", errors="backslashreplace")
            )
    return object_ids, paths


def blob_ids(repository: Path, object_ids: list[str]) -> list[str]:
    if not object_ids:
        return []
    details = git(
        repository,
        "cat-file",
        "--batch-check=%(objectname) %(objecttype)",
        input_bytes=("\n".join(object_ids) + "\n").encode("ascii"),
    )
    return [
        line.split()[0].decode("ascii")
        for line in details.splitlines()
        if len(line.split()) == 2 and line.split()[1] == b"blob"
    ]


def blob_contents(repository: Path, object_ids: list[str]) -> Iterator[tuple[str, bytes]]:
    process = subprocess.Popen(
        ["git", "-C", str(repository), "cat-file", "--batch"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    assert process.stdin is not None
    assert process.stdout is not None
    try:
        for requested_id in object_ids:
            process.stdin.write(requested_id.encode("ascii") + b"\n")
            process.stdin.flush()
            header = process.stdout.readline().split()
            if len(header) != 3 or header[1] != b"blob":
                raise RuntimeError(f"unexpected git cat-file response for {requested_id}")
            size = int(header[2])
            content = process.stdout.read(size)
            if len(content) != size or process.stdout.read(1) != b"\n":
                raise RuntimeError(f"truncated git blob response for {requested_id}")
            yield requested_id, content
    finally:
        process.stdin.close()
        return_code = process.wait()
        if return_code != 0:
            stderr = process.stderr.read().decode("utf-8", errors="replace") if process.stderr else ""
            raise RuntimeError(f"git cat-file failed: {stderr.strip()}")


def display_path(paths: set[str]) -> str:
    return sorted(paths)[0] if paths else "<no recorded path>"


def is_allowed_synthetic_email(match: bytes, paths: set[str]) -> bool:
    return match == SYNTHETIC_EMAIL and paths == {SYNTHETIC_FIXTURE_PATH}


def scan_blob(object_id: str, content: bytes, paths: set[str]) -> set[Finding]:
    findings: set[Finding] = set()
    path = display_path(paths)
    suffixes = {Path(candidate).suffix.lower() for candidate in paths}
    if suffixes & SENSITIVE_SUFFIXES:
        findings.add(Finding("private key or certificate file", object_id, path))
    if suffixes & ARCHIVE_SUFFIXES:
        findings.add(Finding("unexpected binary archive", object_id, path))
    if content.startswith(ARCHIVE_MAGICS) or (
        len(content) > 262 and content[257:262] == b"ustar"
    ):
        findings.add(Finding("unexpected binary archive", object_id, path))
    for category, pattern in CONTENT_PATTERNS:
        if pattern.search(content):
            findings.add(Finding(category, object_id, path))
    if ACCOUNT_ID_PATTERN.search(content):
        findings.add(Finding("account identity", object_id, path))
    for match in EMAIL_PATTERN.finditer(content):
        if not is_allowed_synthetic_email(match.group(0), paths):
            findings.add(Finding("email or account identity", object_id, path))
    return findings


def audit(repository: Path) -> tuple[int, set[Finding]]:
    object_ids, paths_by_id = reachable_objects(repository)
    blobs = blob_ids(repository, object_ids)
    findings: set[Finding] = set()
    for object_id, content in blob_contents(repository, blobs):
        findings.update(scan_blob(object_id, content, paths_by_id.get(object_id, set())))
    return len(blobs), findings


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository", type=Path, default=Path(__file__).resolve().parents[1])
    repository = parser.parse_args().repository.resolve()
    try:
        blob_count, findings = audit(repository)
    except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
        print(f"error: public exposure audit could not inspect Git history: {error}", file=sys.stderr)
        return 2
    if findings:
        for finding in sorted(findings):
            print(
                f"error: {finding.category} in reachable blob "
                f"{finding.object_id[:12]} ({finding.path})",
                file=sys.stderr,
            )
        print("Public exposure Git-history audit failed", file=sys.stderr)
        return 1
    print(
        f"Public exposure Git-history audit passed: {blob_count} reachable blobs inspected; "
        "one exact synthetic fixture allowance enforced"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
