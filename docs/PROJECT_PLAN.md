# Pet Halo Project Plan

## Principles

- Pet Halo remains independent from Codex Desktop and Codex Pet.
- Experimental protocol data is converted into a stable internal model.
- MVP metrics are capability-driven: optional segments appear only when their source is available.
- Missing or unsupported data is hidden or displayed as unavailable, never estimated.
- Each milestone has an explicit gate and does not authorize the next one automatically.

## Milestones

### M0 — Protocol feasibility

Generate schemas from the installed Codex CLI, build a read-only protocol probe, capture redacted fixtures, and assess core and optional capabilities. M0 passes when an owned stdio app-server can connect, return at least one usable account rate-limit window, return account usage, and degrade missing optional data safely. Five-hour and thread Context data are optional. No production UI.

### M1 — Application skeleton

**Complete — PASS.** The macOS/Xcode project, minimal application and test targets, CI, and accessory application lifecycle skeleton are implemented and verified. M1 does not include CodexBridge or Halo UI. See [the M1 report](milestones/m1-application-skeleton.md).

### M2 — CodexBridge

**Complete — PASS.** Stable internal usage models, bounded JSONL/JSON-RPC transport, owned process lifecycle, exact-version detection, read-only refresh/reconnection, redacted diagnostics, deterministic fake-process tests, and local real smoke validation are implemented. See [the M2 report](milestones/m2-codex-bridge.md).

### M3 — Halo window

**Complete — PASS.** A non-activating transparent `NSPanel`, compact click-through and expanded non-activating scrolling, deterministic Usage presentation, menu controls, accessibility states with a fully opaque Reduce Transparency fallback, panel lifecycle, tests, smoke validation, and boundary checks are implemented. See [the M3 report](milestones/m3-halo-window.md).

### M4 — Window following

**Implemented — focused relaunch revalidation pending.** Exact bundle-ID discovery, explicit Accessibility permission, deterministic standard-window selection, coordinate conversion, explicit calibration, a versioned relative anchor, event-driven move/resize following, multi-display visible-frame containment, safe preferences, free-floating fallback, lifecycle cleanup, tests, and smoke tooling are present. Direct validation passed all items except automatic recovery when Codex relaunched before its standard window was ready. That race has a deterministic fix and test; the gate remains `PARTIAL — ACCESSIBILITY PERMISSION MANUAL VALIDATION REQUIRED` until the real relaunch scenario is rechecked. See [the M4 report](milestones/m4-window-following.md).

### M5 — Original visual design

Add original branding, motion preferences, themes, and low-usage states without official OpenAI or Codex Pet artwork.

### M6 — Hardening

Expand compatibility fixtures, transport/reconnect tests, UI/window tests, privacy audits, packaging, and release documentation.
