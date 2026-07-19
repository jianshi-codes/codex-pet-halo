# M0 Protocol Feasibility

- Status: **PASS-CORE / PARTIAL-OPTIONALS**
- Date: 2026-07-20
- Scope: environment evidence, generated protocol schemas, read-only probe, redacted fixtures, tests, and core/optional capability assessment
- Stop condition: M0 evidence complete; do not implement M1 or Halo UI

## Executive result

M0 proves that an independently launched stdio app-server can support the Pet Halo MVP account-data path: connection state, weekly rate limits, reset time, account usage summary, daily usage, and multiple rate-limit buckets. Missing five-hour and shared Context data are optional capabilities and do not block the ambient Halo product.

| Gate | Requirement | Result | Evidence |
| --- | --- | --- | --- |
| CORE-A | Own and connect to a read-only app-server transport | **PASS** | Independent stdio completed `initialize` / `initialized` and all probed requests |
| CORE-B | Read at least one usable Codex rate-limit window | **PASS** | Real 10080-minute weekly windows returned with used percentage and reset time |
| CORE-C | Read account usage for expanded presentation | **PASS** | Summary and daily usage buckets returned |
| CORE-D | Degrade missing optional data safely | **PASS** | Missing buckets/context window, nulls, unknowns, timeout, and disconnect are tested |
| OPTIONAL-5H | Read a 300-minute window when offered | **UNAVAILABLE** | No matching real window; the segment remains absent |
| OPTIONAL-RATE-PUSH | Observe `account/rateLimits/updated` | **UNVERIFIED** | Generated schema exists; no runtime notification observed |
| OPTIONAL-CONTEXT | Receive Desktop thread Context updates | **UNAVAILABLE** | Shared control socket was not running |
| OPTIONAL-TARGET | Select a Desktop target thread | **UNAVAILABLE** | Required only for optional Context display |

The revised product gate is **PASS-CORE / PARTIAL-OPTIONALS**. M0 qualifies the repository for separately authorized M1 skeleton work; this M0 change does not start M1 or Halo UI. Optional data must appear only when supported and must never be estimated.

## Recommended MVP data composition

| Surface | Data | Behavior |
| --- | --- | --- |
| Primary halo | General Codex weekly remaining percentage | Prefer the exact `codex` bucket when present; never select by map order |
| Primary details | Weekly reset time | Show in expanded/hover details |
| Optional segment | Five-hour remaining percentage and reset time | Add only when a 300-minute window exists |
| Status indicator | Halo-to-owned-app-server connection | Distinguish connected, disconnected, timeout, and protocol error |
| Expanded view | Account usage summary, streaks, daily usage, and additional rate-limit buckets | Do not display account identity or raw credentials |
| Optional segment | Target-thread Context remaining | Add only after a supported shared source and explicit target strategy are verified |

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
| Five-hour / 300-minute limit | Optional and currently absent; no matching real window |
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

The probe did not try unrelated IPC sockets, guess a private transport, launch a persistent daemon, modify Desktop, or inspect a Codex database. Therefore shared handshake, `thread/loaded/list`, `thread/status/changed`, and real-time `thread/tokenUsage/updated` are **not verified**. This blocks only the optional Context segment, not the owned stdio account-data MVP.

## Optional target-thread strategy

The generated `thread/loaded/list` response contains only thread IDs and a cursor. When a supported shared transport becomes available:

1. preserve every loaded thread ID and observe its `thread/status/changed` state;
2. never equate “active” protocol status with the Desktop UI's selected task without explicit evidence;
3. if exactly one eligible thread is loaded, offer it as a suggested target;
4. if multiple are loaded, require explicit user selection and persist the selected exact ID only for the local session;
5. if the target unloads or the transport disconnects, clear Context to unavailable.

This strategy remains unverified because it could not be exercised against Desktop. It is not needed while the Context segment is absent.

## Recommended MVP architecture

- Stable internal `UsageSnapshot` model with nullable five-hour, weekly, and context fields.
- Owned independent stdio backend as the primary MVP source for account, rate limits, usage, and connection state.
- Optional shared context backend only through a future CLI-supported, discoverable transport.
- Explicit target-thread picker for multi-thread cases; no UI-focus inference.
- Initial and periodic rate-limit reads; a future sparse-update merger must refetch on ambiguity.
- Fail-closed version compatibility check keyed to generated schema bundles.
- Optional segments disappear or become unavailable on missing data, disconnect, timeout, or unverified semantics.

Recommended MVP transport: an owned `codex app-server --stdio` child process. A future shared control-socket transport may add Desktop Context, but it is not a prerequisite for the Halo.

## Risks and protocol assumptions

- The app-server protocol and schema generators are experimental and may change without compatibility guarantees.
- A five-hour window is currently absent and may return later; the UI must add or remove that segment dynamically.
- Multiple rate-limit buckets must remain distinct; the project must not silently choose one by array or map order.
- `account/rateLimits/updated` is sparse and cannot safely replace a complete snapshot.
- `total.totalTokens / modelContextWindow` is the parser's provisional context calculation; the generated shape supports it, but shared runtime semantics remain unverified.
- Desktop currently owns an ephemeral child transport with no supported external attachment evidence; only optional Context is affected.
- Loaded/active protocol status does not prove Desktop UI selection.
- Account usage history is sensitive behavioral data; the expanded view should minimize retention and never log or persist raw history unnecessarily.
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

## Optional follow-up items

- Obtain a real 300-minute rate-limit window and verify reset/update behavior.
- Observe a real `account/rateLimits/updated` notification.
- Obtain a supported shared transport associated with Codex Desktop.
- Verify shared `thread/loaded/list`, `thread/status/changed`, and real-time `thread/tokenUsage/updated` during an active task.
- Exercise explicit target-thread selection with one and multiple loaded threads.
- Validate context-token semantics across compaction and model changes.

These items require a future environment or protocol change. They do not block M1 eligibility or the account-data MVP. No estimate or substitute data was used.
