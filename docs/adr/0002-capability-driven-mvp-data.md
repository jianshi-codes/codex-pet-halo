# ADR 0002: The MVP is capability-driven and owns its stdio app-server

- Status: Accepted
- Date: 2026-07-20

## Context

The M0 host reliably returned weekly Codex rate limits and account usage through an independently launched stdio app-server. A five-hour window was temporarily absent, and no supported transport exposed the Codex Desktop app-server's loaded thread state.

Neither optional absence prevents Pet Halo from delivering its primary purpose: an ambient usage halo near Codex Pet.

## Decision

The MVP uses an owned `codex app-server --stdio` child process and presents data by capability:

- primary halo: weekly remaining percentage and reset time;
- connection indicator: Halo-to-owned-app-server state;
- expanded view: account usage summary, streaks, daily usage, reset details, and additional rate-limit buckets;
- optional five-hour segment: present only when a 300-minute window exists;
- optional Context segment: present only when a supported shared thread source and explicit target strategy exist.

Optional data is hidden or marked unavailable. It is never synthesized, estimated, or inferred from Codex internal storage. Multiple rate-limit buckets are preserved and never selected by map order.

## Consequences

M0 is PASS-CORE / PARTIAL-OPTIONALS and qualifies the project for separately authorized M1 work. The owned stdio process is sufficient for the MVP account-data path. Shared control-socket and Desktop thread integration remain future enhancements rather than release blockers.
