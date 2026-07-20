# Pet Halo Project Plan

## Principles

- Pet Halo remains independent from Codex Desktop and Codex Pet.
- Experimental protocol data is converted into a stable internal model.
- MVP metrics are capability-driven: optional segments appear only when their source is available.
- Missing or unsupported data is hidden or displayed as unavailable, never estimated.
- Each milestone has an explicit gate and does not authorize the next one automatically.
- Targeting follows a product hierarchy: Pet target following is preferred, calibrated Codex-window following is the permanent fallback, and a free-floating Halo is the final fallback.

## Milestones

### M0 — Protocol feasibility

Generate schemas from the installed Codex CLI, build a read-only protocol probe, capture redacted fixtures, and assess core and optional capabilities. M0 passes when an owned stdio app-server can connect, return at least one usable account rate-limit window, return account usage, and degrade missing optional data safely. Five-hour and thread Context data are optional. No production UI.

### M1 — Application skeleton

**Complete — PASS.** The macOS/Xcode project, minimal application and test targets, CI, and accessory application lifecycle skeleton are implemented and verified. M1 does not include CodexBridge or Halo UI. See [the M1 report](milestones/m1-application-skeleton.md).

### M2 — CodexBridge

**Complete — PASS.** Stable internal usage models, bounded JSONL/JSON-RPC transport, owned process lifecycle, exact-version detection, read-only refresh/reconnection, redacted diagnostics, deterministic fake-process tests, and local real smoke validation are implemented. See [the M2 report](milestones/m2-codex-bridge.md).

### M3 — Halo window

**Complete — PASS.** A non-activating transparent `NSPanel`, compact click-through and expanded non-activating scrolling, deterministic Usage presentation, menu controls, accessibility states with a fully opaque Reduce Transparency fallback, panel lifecycle, tests, smoke validation, and boundary checks are implemented. See [the M3 report](milestones/m3-halo-window.md).

### M4 — Codex Window Following & Fallback

**Complete — PASS.** Exact bundle-ID discovery, explicit Accessibility permission, deterministic standard-window selection, coordinate conversion, explicit calibration, a versioned relative anchor, event-driven move/resize following, multi-display visible-frame containment, safe preferences, free-floating fallback, lifecycle cleanup, tests, smoke tooling, and direct validation are complete. The Codex launch-before-window-ready race found during validation was fixed and passed deterministic plus physical relaunch recovery checks without recalibration. M4 follows the Codex standard window, not the independently movable Codex Pet, and remains the permanent window-level fallback. See [the M4 report](milestones/m4-window-following.md).

### M5 — Pet Target Discovery & Pet-relative Following

Discovery comes first because the Codex Pet implementation is not yet known. Investigate, in order: a separate Codex-owned Accessibility window or panel; a stable Accessibility child element; and only if Accessibility discovery is impossible, a separately authorized visual-detection route that may require Screen Recording. M5 owns Pet-relative geometry and must preserve calibrated Codex-window following and free-floating mode as fallbacks. This roadmap entry does not authorize M5 implementation, Screen Recording, screenshots, OCR, or visual detection.

### M6 — Original Visual Design

Add original branding, motion preferences, themes, low-usage states, and game-like visual design without using official OpenAI or Codex Pet artwork.

### M7 — Hardening & Release Readiness

Expand compatibility fixtures, transport/reconnect tests, UI/window tests, privacy audits, packaging, and release documentation and readiness.
