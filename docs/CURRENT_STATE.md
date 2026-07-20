# Current State

- Milestone: M7 — Pet Ring Surface & Target-aware Presentation
- Route: `ROUTE_A — PET_ACCESSIBILITY_WINDOW`
- Implementation: complete on `m7/pet-ring-presentation`; final live validation pending
- Gate: M7 not yet PASS — M5-M7 live interaction, observer visual confirmation, and independent review remain publication gates
- Target hierarchy: Pet / calibrated Codex standard window / free-floating Halo
- Pet placement invariant: the AX Pet midpoint remains the stable tracking basis; the shared visual ring center is `petFrame.center + PetVisualCenterOffset`
- Geometry boundary: `PetTargetSnapshot` carries the Pet frame, generation, and content-free activity-geometry hint; the fixed M7 surface is `252×252` with three 104/94/84-point rings and a `162`-point transparent center while fallback cards retain `176×176` Compact and `360×520` Expanded sizing
- Persistence: startup deletes the legacy normalized Pet anchor; the M4 Codex-window anchor and the separate versioned fixed visual-center `dx/dy` offset are preserved
- Fine-tune compatibility: menu nudge actions use the retained fine-tune API to persist the fixed visual-center offset without making the Pet panel interactive
- Presentation state: Pet selects `petRing` only; Codex-window/free-floating targets select `compactCard` or `expandedCard`; atomic activation switches surface before applying the centered ring frame, and fallback restores the previous card mode
- Stability: movement, resize, arbitrary fallback presentation-size updates, negative display coordinates, Tuck Away, Wake, restart, and stale generations preserve the target hierarchy and visual-center offset
- Panel: Pet Ring transparent and shadowless / no card material, title container, scrolling, or controls / always click-through / non-activating / cannot become key or main; fallback cards remain intact
- Safe placement status: `Pet placement: Centered` or `Pet placement: Unavailable`
- Privacy: exact `com.openai.codex` only / role, subrole, minimized, hidden, position, size only / activity geometry is an optional post-selection direction hint / no content attributes, screenshots, OCR, databases, analytics, or telemetry
- Pet metrics: outer Weekly and middle exact-300-minute 5h use `remainingPercent`; inner Today uses current-day tokens divided by nonzero historical peak and clamps progress only; rate and Account Usage freshness remain independent
- Orientation: one fixed partial-arc policy; dialog above opens top, dialog below opens bottom, no dialog uses the fixed default, and ambiguous/transient geometry retains the prior debounced direction without moving the panel
- Focused M7 validation: 89 application/presentation/following tests pass with fakes and synthetic geometry; no Codex process or Accessibility permission required
- Full validation: generated-project/source/privacy scans, Debug build/bundle, universal arm64+x86_64 Release build/bundle, all 92 Swift tests, all 14 M0 protocol tests, and whitespace checks pass
- Draft PR CI: Protocol evidence and macOS application jobs pass on pushed commit `9c7a4b9`; current patch CI is pending push
- M2 timing validation: `testSparseNotificationBurstDebouncesToOneCompleteRefreshSeam` passes 30/30 fail-fast repetitions without retry
- Live validation: the current tree sees Accessibility permission, exact Codex/Pet Halo processes, a visible unique Pet, automatic Pet Ring selection, initial visual-center attachment, and non-activation. `make m5-smoke`, `make m6-smoke`, and `make m7-smoke` were run, but fail closed because this validation session could not move Codex Pet or perform Tuck Away/Wake/Quit; post-movement, fallback, recovery, and simultaneous visible-Pet containment remain pending direct interaction
- Retained protocol boundary: M0 remains PASS-CORE / PARTIAL-OPTIONALS; production remains fail-closed to CLI `0.145.0-alpha.18`; no Codex internal database dependency
- Future boundary: M8 owns advanced polish beyond the fixed M7 arc/color policy, themes, decorative low-usage styling, glow, motion preferences, and animations; M9 owns hardening/release readiness

M6 removes the M5 first-use Pet calibration detour and all runtime Pet positional overrides. Once Accessibility following has been explicitly enabled, a unique Pet target attaches immediately. Pet loss, Tuck Away, ambiguity, permission loss, or observer failure uses the preserved M4 window anchor and then M3 free-floating fallback. Wake or deterministic rediscovery restores centered Pet placement without user action.

Target discovery and tracking use no screen lookup, activity-dialog geometry, fit calculation, clamp, or side choice. Direct visual acceptance showed that the rendered character center can differ from the padded Route A AX midpoint, so M7 adds only a constant presentation offset to the complete panel. Activity geometry is evaluated after core selection and changes only partial-arc angles.

The fine-tune API writes only `PetVisualCenterOffset(horizontal, vertical)`. It never creates a normalized Pet anchor or changes discovery, selected target, dialog hint, or fallback. Absolute overlay labels and all concentric rings move together because their center remains the panel midpoint.

M7 replaces only the Pet-target demo card. Compact/Expanded cards and full Account Usage remain available on Codex-window and free-floating fallbacks. The Pet model uses peak daily tokens only as Today's denominator and contains no lifetime, streak, longest-turn, or seven-day presentation. Fixed partial arcs, semantic system colors, textual freshness, and per-ring accessibility are functional M7 treatment only; there is no final artwork, theme system, glow, particle, pulse, sound, or animation work.
