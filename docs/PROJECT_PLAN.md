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

**Complete — Route A implemented.** Local discovery proved one logical near-square `AXWindow/AXDialog` frame that follows independent Pet movement while the standard Codex window remains stationary. M5 adds deterministic Pet selection, optional manual Pet-relative calibration with a separate versioned anchor, event coalescing, loss fallback, recreation recovery, safe status/menu controls, tests, smoke tooling, and privacy boundaries. Calibrated M4 window following and M3 free-floating placement remain permanent fallbacks. No Screen Recording, screenshots, OCR, or visual detection was added. See [the M5 report](milestones/m5-pet-target-following.md) and [discovery evidence](milestones/m5-pet-target-discovery-report.md).

### M6 — Automatic Center-Locked Pet Attachment

**Complete — PASS.** A unique Pet attaches immediately through an atomic Target Pet → Compact → fixed `176×176` centered layout transition and unconditionally keeps the Halo panel midpoint equal to the Pet midpoint. Fallback Compact/Expanded sizing is independent from Pet attachment. Legacy Pet positional anchors are deleted by a safe migration; the M4 window anchor, fallback/recovery, lifecycle, safe status, tests, and sanitized center-alignment smoke tooling remain intact. The corrected complete live harness passed initial, post-movement, and post-Wake midpoint equality plus Tuck Away fallback, Quit, observer exit, and owned child cleanup. See [the M6 report](milestones/m6-automatic-pet-attachment.md).

### M7 — Pet Ring Surface & Target-aware Presentation

**Implemented — final gate validation pending.** Pet uses only a transparent, click-through, center-locked vector ring. A target-aware surface state preserves Compact/Expanded cards for Codex-window and free-floating fallbacks, rejects card requests on Pet, and restores the prior card mode on loss. The Pet-specific mapper exposes weekly remaining, an exact capability-gated five-hour window, and only the current calendar-day token bucket with independent component freshness. See [the M7 report](milestones/m7-pet-ring-presentation.md).

### M8 — Visual Polish, Themes & Motion

Add advanced styling, arc orientation, themes, low-usage visuals, motion preferences, and animation without using official OpenAI or Codex Pet artwork.

### M9 — Hardening & Release Readiness

Expand compatibility fixtures, transport/reconnect tests, UI/window tests, privacy audits, packaging, and release documentation and readiness.
