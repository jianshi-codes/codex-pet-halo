# Current State

- Milestone: M6 — Automatic Center-Locked Pet Attachment
- Route: `ROUTE_A — PET_ACCESSIBILITY_WINDOW`
- Implementation: complete on `m6/automatic-pet-attachment`
- Gate: implementation, deterministic/full regression, and direct interaction pass; Draft PR CI and independent review remain required before final PASS
- Target hierarchy: Pet / calibrated Codex standard window / free-floating Halo
- Pet placement invariant: whenever the selected target is Pet, the Halo panel midpoint equals the Pet AX frame midpoint
- Geometry boundary: `PetTargetSnapshot` carries only the Pet frame and generation; `PetAttachmentLayout` carries only the logical reference point and centered panel frame
- Persistence: startup deletes the legacy Pet anchor key; the M4 Codex-window anchor is preserved
- Fine-tune compatibility: the fine-tune API remains callable but has no positional effect and cannot override center lock; its menu commands and Pet calibration state are removed
- Presentation guard: Pet targeting forces Compact and rejects Expanded; leaving Pet restores the previous fallback card mode and normal mode controls
- Stability: movement, resize, panel-size changes, negative display coordinates, Tuck Away, Wake, and stale generations preserve the established hierarchy and exact center rule
- Panel: current demo card retained / non-activating / cannot become key or main / compact click-through / expanded available only outside Pet targeting
- Safe placement status: `Pet placement: Centered` or `Pet placement: Unavailable`
- Privacy: exact `com.openai.codex` only / role, subrole, minimized, hidden, position, size only / no content attributes, screenshots, OCR, databases, analytics, or telemetry
- Focused M6 validation: 58 deterministic application tests pass with fakes and synthetic geometry; no Codex process or Accessibility permission required
- Full validation: source/privacy scans, Debug build, universal arm64+x86_64 Release, 121 Swift tests pass with one designed local-only skip, and 14 M0 protocol tests pass
- M2 timing validation: `testSparseNotificationBurstDebouncesToOneCompleteRefreshSeam` passes 30/30 fail-fast repetitions without retry
- Live validation: M2-M5 smoke pass; sanitized M6 observation captured Pet movement, exact center after movement, M4 fallback, Wake exact-center recovery, Quit, and cleanup, with direct user visual confirmation
- Retained protocol boundary: M0 remains PASS-CORE / PARTIAL-OPTIONALS; production remains fail-closed to CLI `0.145.0-alpha.18`; no Codex internal database dependency
- Future boundary: M7 owns the functional Pet ring and basic Usage presentation, M8 owns visual polish/themes/motion, and M9 owns hardening/release readiness

M6 removes the M5 first-use Pet calibration detour and all runtime Pet positional overrides. Once Accessibility following has been explicitly enabled, a unique Pet target attaches immediately. Pet loss, Tuck Away, ambiguity, permission loss, or observer failure uses the preserved M4 window anchor and then M3 free-floating fallback. Wake or deterministic rediscovery restores centered Pet placement without user action.

Center placement uses no screen lookup, activity-dialog geometry, above/below decision, fit calculation, clamp, side stability, or orientation metadata. Direct screenshots showed that edge inference over the padded Route A Pet surface was unstable; the accepted policy therefore depends only on the Pet frame midpoint. Future artwork may move inside the transparent center-locked panel without reopening M6 target placement.

The fine-tune API is intentionally retained for compatibility with callers, but it is a no-op for Pet positioning. It creates no calibration state, writes no Pet anchor, exposes no menu action, and cannot move the panel away from the Pet midpoint.

The current demo card is intentionally unchanged. The temporary Compact guard prevents the 360×520 Expanded card from covering Pet until M7 replaces the demo surface with the functional Pet ring. M6 adds no final artwork, semantic colors, decorative motion, particles, sound, themes, packaging, or release work.
