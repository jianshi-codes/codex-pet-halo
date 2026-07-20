# Current State

- Milestone: M7 — Pet Ring Surface & Target-aware Presentation
- Route: `ROUTE_A — PET_ACCESSIBILITY_WINDOW`
- Implementation: complete on `m7/pet-ring-presentation`; final live validation pending
- Gate: M7 not yet PASS — M5-M7 live interaction, observer visual confirmation, and independent review remain publication gates
- Target hierarchy: Pet / calibrated Codex standard window / free-floating Halo
- Pet placement invariant: whenever the selected target is Pet, the Halo panel midpoint equals the Pet AX frame midpoint
- Geometry boundary: `PetTargetSnapshot` carries only the Pet frame and generation; the fixed M7 ring is `208×208` with a `158`-point transparent center while fallback cards retain `176×176` Compact and `360×520` Expanded sizing
- Persistence: startup deletes the legacy Pet anchor key; the M4 Codex-window anchor is preserved
- Fine-tune compatibility: the fine-tune API remains callable but has no positional effect and cannot override center lock; its menu commands and Pet calibration state are removed
- Presentation state: Pet selects `petRing` only; Codex-window/free-floating targets select `compactCard` or `expandedCard`; atomic activation switches surface before applying the centered ring frame, and fallback restores the previous card mode
- Stability: movement, resize, arbitrary fallback presentation-size updates, negative display coordinates, Tuck Away, Wake, and stale generations preserve the established hierarchy and exact center rule
- Panel: Pet Ring transparent and shadowless / no card material, title container, scrolling, or controls / always click-through / non-activating / cannot become key or main; fallback cards remain intact
- Safe placement status: `Pet placement: Centered` or `Pet placement: Unavailable`
- Privacy: exact `com.openai.codex` only / role, subrole, minimized, hidden, position, size only / no content attributes, screenshots, OCR, databases, analytics, or telemetry
- Pet metrics: weekly uses domain `remainingPercent`; 5h requires an exact 300-minute capability; Today tokens require exactly one bucket matching the injected Calendar day; rate and Account Usage freshness remain independent
- Focused M7 validation: 79 application/presentation/following tests pass with fakes and synthetic geometry; no Codex process or Accessibility permission required
- Full validation: generated-project/source/privacy scans, Debug build/bundle, universal arm64+x86_64 Release build/bundle, all 82 Swift tests, all 14 M0 protocol tests, and whitespace checks pass
- Draft PR CI: Protocol evidence and macOS application jobs pass on pushed commit `9c7a4b9`
- M2 timing validation: `testSparseNotificationBurstDebouncesToOneCompleteRefreshSeam` passes 30/30 fail-fast repetitions without retry
- Live validation: current-tree M2 and M3 lifecycle smokes pass; M4 deterministic/accessibility/lifecycle smoke completes with the standard window currently unavailable; M5-M7 are blocked until one visible unique Pet and one normal Codex window are present
- Retained protocol boundary: M0 remains PASS-CORE / PARTIAL-OPTIONALS; production remains fail-closed to CLI `0.145.0-alpha.18`; no Codex internal database dependency
- Future boundary: M8 owns advanced polish, angle/orientation changes, themes, low-usage styling, glow, motion preferences, and animations; M9 owns hardening/release readiness

M6 removes the M5 first-use Pet calibration detour and all runtime Pet positional overrides. Once Accessibility following has been explicitly enabled, a unique Pet target attaches immediately. Pet loss, Tuck Away, ambiguity, permission loss, or observer failure uses the preserved M4 window anchor and then M3 free-floating fallback. Wake or deterministic rediscovery restores centered Pet placement without user action.

Center placement uses no screen lookup, activity-dialog geometry, above/below decision, fit calculation, clamp, side stability, or orientation metadata. Direct screenshots showed that edge inference over the padded Route A Pet surface was unstable; the accepted policy therefore depends only on the Pet frame midpoint. Future artwork may move inside the transparent center-locked panel without reopening M6 target placement.

The fine-tune API is intentionally retained for compatibility with callers, but it is a no-op for Pet positioning. It creates no calibration state, emits no movement or calibration-enabled event, writes no Pet anchor, exposes no menu action, and cannot move the panel away from the Pet midpoint. Future visual fine-tuning must use a new visual-orientation API inside the fixed transparent panel rather than restoring Pet positional offsets.

M7 replaces only the Pet-target demo card. Compact/Expanded cards and full Account Usage remain available on Codex-window and free-floating fallbacks. The Pet model cannot contain summary/history fields and never treats a missing daily bucket as zero. Fixed arc geometry, textual freshness/remaining-level states, and accessibility semantics are functional M7 treatment only; there is no final artwork, theme system, glow, particle, pulse, sound, or animation work.
