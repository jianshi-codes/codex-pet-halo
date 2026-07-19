# M2 CodexBridge

- Status: **PASS**
- Date: 2026-07-20
- Scope: stable Usage domain, bounded JSON-RPC transport, owned local app-server, exact compatibility gate, read-only refresh/reconnect service, lifecycle integration, deterministic tests, local real smoke, documentation, and CI
- Stop condition: M2 implementation committed; do not implement M3 Halo/Usage UI or window behavior

## Implemented architecture

`PetHaloCore` is a Swift 6 framework with complete strict-concurrency checking. It owns UI-independent Usage models and the Codex bridge. `PetHalo` depends on the framework and owns the application lifecycle; `PetHaloCoreTests` contains the transport/service suite and a fake process resource that is excluded from the app bundle.

The stable model preserves all returned rate-limit buckets and identifies the general bucket only by exact `codex` ID. A weekly window is exactly 10,080 minutes and a five-hour window exactly 300 minutes; storage slots and map order never imply semantics. Used percentage is clamped once at the domain boundary and remaining percentage is derived there. `UsageComponentFreshness` exposes rate-limit and Account Usage freshness independently. Global freshness is derived from the available snapshot components: any included stale component makes the snapshot stale, while an optional unavailable component does not make current data stale. Missing, ambiguous, unsupported, stale, authentication-unavailable, and transport-failed data remain distinguishable. Context is explicitly unsupported in M2.

## Transport and lifecycle

The bridge discovers an executable without a shell, ignores relative `PATH` entries, checks the exact supported CLI version, launches `codex app-server --stdio`, performs initialize/initialized, and uses only three account read methods. The version probe has a 5-second default timeout and 4 KiB stdout cap; timeout/cancellation terminates, escalates when needed, and awaits confirmed exit. JSONL framing supports partial and multiple messages, rejects invalid UTF-8 and messages over 4 MiB, and fails closed if its bounded delivery queue overflows. JSON-RPC uses monotonic IDs, concurrent pending continuations, serialized writes, out-of-order responses, deterministic timeouts, cancellation/disconnect propagation, and explicit duplicate/unknown-ID behavior.

The child owns its pipes, drains and discards stderr, closes stdin, requests termination, waits, and escalates to kill only after a bounded grace period. JSON-RPC close/disconnect creates exactly one awaitable transport-cleanup barrier; all concurrent closes wait for it, and disconnect is published only after it completes. Each service connection attempt carries an immutable epoch checked after every suspension. Stop invalidates and cancels the epoch, then awaits attempt-owned version/process cleanup, so an obsolete attempt cannot publish, reconnect, or overwrite `.stopped`. Application termination is deferred until those barriers complete.

## Refresh and recovery

Initial reads are sequential and read-only. Rate limits refresh every 60 seconds and Account Usage every 15 minutes on absolute monotonic schedules. Refresh work coalesces into ordered `rateLimitsOnly < fullAccount` scopes: one refresh runs at a time, incoming work merges into one strongest pending scope, and the follow-up runs immediately. A failed Usage read may retain same-account Usage only with component freshness `.stale` and its safe failure reason preserved; an unrelated successful rate-only refresh cannot make it current or erase that failure. A later successful full refresh replaces the retained Usage, restores its freshness, and clears the failure. `account/rateLimits/updated` marks only retained rate data stale until a complete refetch. `account/updated` immediately clears all account-scoped data and schedules `account/read`, rate-limit, and Usage reads; a later rate notification cannot downgrade it. Authentication loss clears every account capability. Because identity is deliberately discarded, every new app-server connection also clears prior account data rather than assuming account continuity. Reconnect delays are bounded exponential steps of 1, 2, 4, 8, 16, 30, and 60 seconds with injected jitter. Intentional stop clears pending work and prevents relaunch.

`UsageSnapshot.collectedAt` and `CodexUsageState.lastSuccessfulRefresh` represent the newest successful snapshot-component mutation. They do not assert that every included component was collected at that instant; consumers must use `componentFreshness` for individual recency.

## Privacy and compatibility

The compatibility registry accepts only Codex CLI `0.145.0-alpha.18`. Unknown versions fail before launch. Minimal owned DTOs ignore unknown response fields; generated schemas, M0 probe code, fixtures, and the fake server are not production dependencies or app resources.

Diagnostics are limited to fixed events, safe failure enums, and reconnect attempt counts. The bridge never logs raw JSON, stderr/stdout, remote error text, paths, environment values, identity fields, or Usage values, and it persists no Codex data.

## Verification

| Evidence | Result |
| --- | --- |
| `make m2-tests` | PASS — 51 Core tests (1 local-only smoke skipped normally) and 5 lifecycle/menu-state tests, 0 failures |
| JSONL/JSON-RPC cases | PASS — framing, 4 MiB bound, IDs, concurrency, ordering, timeout, cancel, disconnect, duplicate/unknown IDs, malformed data |
| Fake process cases | PASS — valid, partial stdout, stderr noise, malformed/oversized/hanging version output, abrupt exit, auth/account transitions, optional Usage failure, sparse/burst notifications |
| Service cases | PASS — attempt invalidation, exact cleanup barrier, max owned-child concurrency 1, component freshness and recovery, account isolation, refresh coalescing, reconnect, idempotent/concurrent shutdown |
| `make check` | PASS — Debug/Release builds, all Swift tests, retained M0 tests, bundle/privacy/source/project drift checks |
| `make m2-smoke` | PASS — local executable/version/handshake/read capabilities and clean owned-child shutdown; sanitized output only |
| Launch Services smoke | PASS — accessory process, no visible normal window, no Dock icon by policy, owned child exits with app |
| Menu observation | PASS — technical `Bridge: Connected` state only; no quota or Halo UI |

CI runs `make check` with the deterministic fake transport path. It does not install Codex, use a real authenticated server, or run the local smoke target.

## Gate

The M2 exit criteria pass. The next recommended milestone is separately authorized **M3 — Halo window**. This result does not authorize or begin M3.
