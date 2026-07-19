# M0 Protocol Feasibility

- Status: **BLOCKED**
- Date: 2026-07-20
- Scope: environment evidence, generated protocol schemas, read-only probe, redacted fixtures, tests, and PASS-A/B/C assessment
- Stop condition: M0 evidence complete; do not implement M1 or Halo UI

## Executive result

M0 proves that an independently launched app-server can read account data, weekly rate limits, and account token-usage history on this machine. It does **not** prove the two core prerequisites for the product: the real response contained no five-hour window, and the CLI-supported shared control socket was not running, so Pet Halo could not observe Codex Desktop thread context.

| Gate | Requirement | Result | Evidence |
| --- | --- | --- | --- |
| PASS-A | Reliably read five-hour and weekly limits | **FAIL** | Weekly windows were real and parseable; no 300-minute window was present |
| PASS-B | Receive context updates from the app-server used by Codex Desktop | **BLOCKED** | `app-server proxy` could not connect; no shared handshake or token-usage event |
| PASS-C | Select the target thread reliably or provide a reliable user-selection fallback | **BLOCKED** | Shared loaded/active thread inventory was unavailable |

At least PASS-A is required to enter M1, so **M1 is not recommended or authorized**. Without PASS-B, future UI must display Context as unavailable and must never estimate it.

## Environment evidence

| Component | Result |
| --- | --- |
| macOS | 26.5.2, Build 25F84, arm64 |
| Xcode | 26.4.1, Build 17E202 |
| Swift | 6.3.1, arm64-apple-macosx26.0 target |
| Codex CLI | `codex-cli 0.145.0-alpha.18` |
| Codex Desktop | bundle `com.openai.codex`, version 26.715.31925, build 5551 |
| Git | 2.53.0 |
| GitHub CLI | 2.87.3; authenticated |
| GitHub API login | `jianshi-codes` |

No authentication token, header, cookie, full account record, or credential is included in this report.

## Generated schema evidence

The installed CLI exposed `app-server`, `daemon`, `proxy`, `generate-json-schema`, and `generate-ts`. Both schema commands completed successfully with `--experimental`:

```sh
codex app-server generate-json-schema --experimental \
  --out Tools/ProtocolProbe/Schemas/0.145.0-alpha.18/json

codex app-server generate-ts --experimental \
  --out Tools/ProtocolProbe/Schemas/0.145.0-alpha.18/typescript
```

The versioned bundle contains 341 JSON files and 685 TypeScript files. The CLI-generated directories were not edited. Project metadata is in `GENERATION.md` beside them.

Relevant true structures:

- `account/rateLimits/read` returns `rateLimits`, nullable `rateLimitsByLimitId`, and nullable reset-credit metadata.
- `RateLimitSnapshot` has nullable `primary` and `secondary` windows; neither name is assigned a duration semantic.
- `RateLimitWindow` contains numeric `usedPercent`, nullable `windowDurationMins`, and nullable epoch-seconds `resetsAt`.
- `account/rateLimits/updated` is a sparse notification containing one `RateLimitSnapshot`; generated comments require merging with the last read response or refetching.
- `account/usage/read` returns a summary and nullable daily usage buckets.
- `thread/tokenUsage/updated` contains `threadId`, `turnId`, and `tokenUsage`; token usage has `total`, `last`, and nullable `modelContextWindow`.

## Account probe

Command:

```sh
python3 Tools/ProtocolProbe/probe.py \
  --transport stdio --timeout 15 --observe-seconds 1 \
  --output-dir Tests/Fixtures/CodexProtocol
```

Results:

| Check | Result |
| --- | --- |
| `initialize` / `initialized` | PASS |
| `account/read` | PASS; account identity redacted |
| `account/rateLimits/read` | PASS |
| Five-hour / 300-minute limit | **Unavailable: no matching real window** |
| Weekly / 10080-minute limit | PASS; two distinct buckets returned |
| Multiple buckets | PASS; `codex` and `codex_bengalfox` observed |
| `account/usage/read` | PASS; high-volume token metrics redacted and compacted in fixture |
| `account/rateLimits/updated` | Schema-confirmed, but no real notification observed |

At capture time the `codex` weekly bucket reported 3% used (97% remaining), resetting at 2026-07-26T15:02:46Z. A second weekly bucket reported 0% used. These are time-specific feasibility observations, not stable quotas or product guarantees.

## Shared app-server probe

Current CLI evidence establishes the discovery contract without hardcoding:

```sh
codex app-server proxy --help
codex app-server daemon version
codex doctor --json
python3 Tools/ProtocolProbe/probe.py \
  --transport proxy --timeout 8 --observe-seconds 1 \
  --output-dir /tmp/pet-halo-m0-proxy
```

- `proxy` is documented as forwarding stdio to the running app-server control socket; `--sock` is optional.
- Default discovery failed because the control socket did not exist.
- `daemon version` independently failed to connect to the same default control-socket location.
- `doctor` reported the background app server as not running in ephemeral mode.
- The running Desktop app had no CLI-advertised pathname to attach to; observed Desktop↔Codex communication used unnamed socketpairs.

The probe did not try unrelated IPC sockets, guess a private transport, launch a persistent daemon, modify Desktop, or inspect a Codex database. Therefore shared handshake, `thread/loaded/list`, `thread/status/changed`, and real-time `thread/tokenUsage/updated` are **not verified**.

## Target-thread strategy

The generated `thread/loaded/list` response contains only thread IDs and a cursor. When a supported shared transport becomes available:

1. preserve every loaded thread ID and observe its `thread/status/changed` state;
2. never equate “active” protocol status with the Desktop UI's selected task without explicit evidence;
3. if exactly one eligible thread is loaded, offer it as a suggested target;
4. if multiple are loaded, require explicit user selection and persist the selected exact ID only for the local session;
5. if the target unloads or the transport disconnects, clear Context to unavailable.

This is a reliable design fallback, but PASS-C remains blocked because it could not be exercised against Desktop.

## Recommended architecture after the gate is unblocked

- Stable internal `UsageSnapshot` model with nullable five-hour, weekly, and context fields.
- Optional shared context backend using only a CLI-supported, discoverable control socket.
- Independent stdio account backend as fallback for rate limits and account usage.
- Explicit target-thread picker for multi-thread cases; no UI-focus inference.
- Sparse rate-limit update merger that refetches on ambiguity.
- Fail-closed version compatibility check keyed to generated schema bundles.
- Context state becomes unavailable on missing `modelContextWindow`, disconnect, timeout, or unverified semantics.

Recommended production transport: a future CLI-supported shared control-socket transport after it is demonstrably associated with Codex Desktop. Recommended fallback: independent stdio for account data only, with Context unavailable.

## Risks and protocol assumptions

- The app-server protocol and schema generators are experimental and may change without compatibility guarantees.
- A five-hour window is not guaranteed for every account, plan, model, or bucket.
- Multiple rate-limit buckets must remain distinct; the project must not silently choose one by array or map order.
- `account/rateLimits/updated` is sparse and cannot safely replace a complete snapshot.
- `total.totalTokens / modelContextWindow` is the parser's provisional context calculation; the generated shape supports it, but shared runtime semantics remain unverified.
- Desktop currently owns an ephemeral child transport with no supported external attachment evidence.
- Loaded/active protocol status does not prove Desktop UI selection.
- Account usage history is sensitive behavioral data and should not be needed by the production Halo unless a later milestone explicitly justifies it.
- The aggregate v2 schema definition order is non-deterministic across runs; canonical JSON was equal, so byte hashes of that aggregate are not a safe compatibility key.

## Fixtures and tests

The committed stdio fixture is derived from a real response, then recursively redacted before disk write. Unknown strings, credentials, IDs, account details, content, paths, and token-count metrics are removed. Daily arrays are compacted after the observed shape is preserved. The shared failure fixture records only the supported discovery outcome.

Test coverage includes:

- five-hour and weekly recognition by duration rather than slot;
- used-to-remaining conversion and clamping;
- missing buckets, nulls, unknown fields, and multiple buckets;
- missing context window;
- JSON-RPC request IDs and notification handling;
- disconnect and timeout errors;
- diagnostic and fixture redaction;
- parsing of committed real fixtures.

## Quality and self-review result

| Check | Result |
| --- | --- |
| Unit and fixture tests | PASS, 14 tests |
| Python compile check | PASS |
| Generated JSON parsing | PASS, 341 files |
| Generated schema reproduction | PASS semantically; individual files identical, aggregate canonical SHA-256 identical |
| `git diff --check` | PASS |
| High-confidence credential scan | PASS, no matches |
| User absolute-path scan | PASS, no matches |
| Python formatter/linter | Not run: `ruff`, `black`, and `mypy` are not installed; code uses standard-library-only style and compile/tests passed |

Self-review fixed four concrete issues before closure: token-history numbers were initially retained in the temporary fixture, blocked-transport diagnostics were initially over-redacted, process shutdown could close reader streams before child termination, and byte-level schema reproduction initially appeared to fail because aggregate definition order is non-deterministic. The committed fixture redacts/compacts token history, diagnostics now preserve causes while removing paths, shutdown ordering is deterministic, and compatibility guidance uses canonical JSON rather than aggregate byte order.

## Complete validation commands

```sh
sw_vers
uname -m
xcodebuild -version
swift --version
codex --version
codex app-server --help
codex app-server generate-json-schema --help
codex app-server generate-ts --help
codex app-server daemon --help
codex app-server proxy --help
git --version
gh --version
gh auth status
gh api user --jq '{login: .login, id: .id}'

python3 -m unittest discover -s Tests -p 'test_*.py' -v
python3 -m compileall -q Tools/ProtocolProbe Tests
git diff --check
git diff --cached --check

rg -n '/Users/[A-Za-z0-9._-]+/' . --hidden -g '!.git/**'
rg -n '(gh[opusr]_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9_-]{20,}|Bearer[[:space:]]+[A-Za-z0-9._~+/=-]{20,})' \
  . --hidden -g '!.git/**'
git status -sb
```

The generated schema bundle must also be checked separately for accidental local paths; generated protocol type names containing words such as “token” are expected and are not credentials.

## Unfinished items

- Obtain a real 300-minute rate-limit window and verify reset/update behavior.
- Observe a real `account/rateLimits/updated` notification.
- Obtain a supported shared transport associated with Codex Desktop.
- Verify shared `thread/loaded/list`, `thread/status/changed`, and real-time `thread/tokenUsage/updated` during an active task.
- Exercise explicit target-thread selection with one and multiple loaded threads.
- Validate context-token semantics across compaction and model changes.

These items require a future environment or protocol change. No estimate or substitute data was used.
