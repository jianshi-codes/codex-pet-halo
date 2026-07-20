# Current State

- Milestone: M8 — Release UI Polish
- Route: `ROUTE_A — PET_ACCESSIBILITY_WINDOW`
- Status: **LOCAL VALIDATION COMPLETE — DRAFT PR CI PENDING**
- Branch: `m8/release-ui-polish`
- Gate: Draft PR CI is the only remaining requirement before M8 is PASS
- Next milestone: M9 — Public Beta Release Readiness; not started and not authorized by M8

## Preserved contracts

- Target hierarchy: Pet / explicitly shown calibrated Codex standard window / free-floating Halo; Pet loss hides Halo by default
- Discovery: exact `com.openai.codex`; unique stable near-square `AXSystemDialog`, with near-square `AXDialog` only as a compatibility fallback; ambiguity fails closed
- Placement: `panel.center = petFrame.center + PetVisualCenterOffset`; no M8 screen-space policy can move that center
- Geometry: transparent `448×252` Pet Ring panel, 104/94/84-point radii, 6-point strokes, and `162`-point transparent center unchanged; fallback cards remain `176×176` Compact and `360×520` Expanded
- Usage: Weekly remaining, optional exact-300-minute 5h remaining, and Codex UTC Today tokens versus nonzero historical peak; missing values are omitted/unavailable and never estimated
- Bridge/freshness: one read-only owned app-server, independent rate and Account Usage freshness, exact supported CLI `0.145.0-alpha.18`, no Codex database access
- Privacy: Accessibility geometry/structure only; no titles, content, screenshots/OCR, Screen Recording, analytics, telemetry, or new network/cloud service

## M8 implementation

- Appearance: live light/dark, Increase Contrast, Differentiate Without Color, and Reduce Transparency inputs update system-based Pet Ring, capsule, connector, track, and fallback treatment; stale/unavailable use dash/glyph/text/accessibility semantics rather than color alone
- Capsule identity: dots remain Weekly `#5865F2`, 5h `#00B8D9`, Today `#A855F7`; related key-text variants meet the deterministic 4.5:1 practical contrast floor; values remain system label text
- Capsule side: dialog geometry chooses only arc opening; selected-display `visibleFrame` separately chooses the fully contained label side, supports negative/multi-display coordinates, adds an 8-point no-clipping settle inset, and persists no screen identity
- Spacing: 24-point capsules, 30-point visible-metric stack, 6-point identity dots, 4-point text spacing, and 10-point Ring gap; optional 5h/Today omission recenters the remaining stack; fixed scaling keeps compact K/M/B values on one line
- Motion: normal latest-value display-linked following is unchanged; Reduce Motion updates directly, starts no display link, and invalidates an active callback on a runtime setting change
- Icons: original Core Graphics AppIcon sizes 16–1024 plus a separate 18/36-pixel monochrome template MenuBarIcon; no official/copied artwork or third-party font/library
- Non-goals: no theme system, decorative animation, particles, glow, sound, packaging, signing, notarization, GitHub Release automation, protocol change, target change, or fallback change

## Validation

- Focused M8: PASS — 105 Swift tests and 2 deterministic asset checks
- Covers: appearance policies, key-text contrast, safe left/right edges, visible-frame containment, negative displays, dialog/side separation, center invariance, hysteresis, Reduce Motion runtime changes, normal follower regression, optional metrics, large values/text, icon catalog, and template configuration
- Full `make check`: PASS — source/privacy/bundle boundaries, Debug, universal `arm64+x86_64` Release, 51 Core tests with one designed local-only skip, 116 App tests, and 16 Python tests
- Retained M2–M7 smoke: PASS — M7 harness follows the current default-hide contract rather than requiring an obsolete automatic fallback card
- `make m8-smoke`: PASS — appearance, contrast, edge placement, motion, layout, and compiled icon checks
- Manual: PASS — light/dark, Increase Contrast, Reduce Motion, both screen edges, menu/App icon surfaces, Pet movement, Tuck Away default hide, Wake, and Quit; current Today-present/5h-absent capability state observed without estimating unavailable combinations
- Draft PR CI: pending publication
