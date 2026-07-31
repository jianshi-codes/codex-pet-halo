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

**Complete — Route A implemented.** Local discovery proved one logical near-square `AXWindow/AXDialog` frame that follows independent Pet movement while the standard Codex window remains stationary. Historical M5 behavior included optional manual Pet-relative calibration with a separate versioned anchor; M6 superseded and removed that positional model. Deterministic Pet selection, event coalescing, loss fallback, recreation recovery, safe status/menu controls, tests, smoke tooling, and privacy boundaries remain relevant. Calibrated M4 window following and M3 free-floating placement are permanent fallbacks. No Screen Recording, screenshots, OCR, or visual detection was added. See [the M5 report](milestones/m5-pet-target-following.md) and [discovery evidence](milestones/m5-pet-target-discovery-report.md).

### M6 — Automatic Center-Locked Pet Attachment

**Complete — PASS.** A unique Pet attaches immediately through an atomic Target Pet → Compact → fixed `176×176` centered layout transition and unconditionally keeps the Halo panel midpoint equal to the Pet midpoint. Fallback Compact/Expanded sizing is independent from Pet attachment. M6 migrated away from the historical Pet positional anchor; no normalized Pet anchor exists in the current state. The M4 window anchor, fallback/recovery, lifecycle, safe status, tests, and sanitized center-alignment smoke tooling remain intact. The corrected complete live harness passed initial, post-movement, and post-Wake midpoint equality plus Tuck Away fallback, Quit, observer exit, and owned child cleanup. See [the M6 report](milestones/m6-automatic-pet-attachment.md).

### M7 — Pet Ring Surface & Target-aware Presentation

**Complete — PASS (historical gate).** M7 established the transparent,
click-through vector Pet surface, fixed concentric geometry, Weekly and optional
exact 300-minute 5h rings, the original Today ring, dialog-aware opening,
latest-value following, restart recovery, fallback preservation, and calibrated
center persistence. Its focused and complete validation, CI, live smoke, visual
acceptance, and independent review passed before PR #8 merged on 2026-07-20.

Current source preserves the M7 surface, geometry, Weekly/5h semantics, and
fallbacks but supersedes the Today data contract through
[ADR 0012](adr/0012-reserved-context-ring-slot.md). The inner slot is now hidden
and reserved for a future exact Context Remaining source; Accessibility geometry
chooses only the arc opening and is never exposed as idle/working state. See the
[historical M7 report](milestones/m7-pet-ring-presentation.md).

### M8 — Release UI Polish

**Complete — PASS.** Live light/dark and accessibility treatment, appearance-aware metric-key contrast, visible-frame-safe capsule sides without moving the Ring center, direct Reduce Motion following, original AppIcon and monochrome template menu icon, normalized spacing, deterministic tests, smoke tooling, and documentation are implemented. Full regression, universal Release, retained smoke, direct appearance/live-Pet acceptance, and CI passed. Pet discovery, Usage semantics, target hierarchy, panel centering, bridge behavior, and fallback architecture remain unchanged. M8 adds no theme system, decorative animation, glow, particles, sound, packaging, signing, notarization, or release automation. PR #9 merged on 2026-07-20. See [the M8 report](milestones/m8-release-ui-polish.md).

### M9 — Public Beta Release Readiness

**Complete with partial gate — `PARTIAL — SOURCE RELEASE READY, SIGNED BINARY BLOCKED`.** PRs #10 and #11 merged on 2026-07-21. The repository is public, and Beta 1 plus its unsigned Universal ZIP and checksum metadata were published on 2026-07-21. PRs #14 and #15 subsequently merged, and `v0.1.0-beta.2` plus its unsigned Universal ZIP and checksum metadata were published on 2026-07-21. PRs #17 and #18 merged on 2026-07-25, and `v0.1.0-beta.3` plus its unsigned Universal ZIP and checksum metadata were published as an Unsigned Developer Preview from commit `e8480a0443783e05dd871f5c248157633a84d9c5`; the user explicitly promoted the verified Release to Latest. PR #20 merged on 2026-07-31, and `v0.1.0-beta.4` was published as an Unsigned Developer Preview from commit `beb0c2c925d04fccf650205a611a1a20d22ead75`. Compatibility hardening, onboarding, privacy/security/legal evidence, reproducible packaging, sanitized issue forms, and collision-safe future release automation are in place. Developer ID signing, Apple notarization, stapling, Gatekeeper verification, and signed clean-machine acceptance remain incomplete and require a new release identity. See [the M9 report](milestones/m9-public-beta-readiness.md).

Post-release defaults reserve `v0.1.0-beta.5` / build `5` as the next unused
identity. Preparing it does not authorize creating a tag, signing, notarizing,
or publishing.
