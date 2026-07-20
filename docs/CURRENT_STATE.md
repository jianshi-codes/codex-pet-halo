# Current State

- Milestone: M6 — Automatic Pet Attachment & Adaptive Placement
- Route: `ROUTE_A — PET_ACCESSIBILITY_WINDOW`
- Implementation: complete on `m6/automatic-pet-attachment`
- Gate: deterministic M6 suite and full regression/build pass; direct comprehensive interaction, Draft PR CI, and independent review remain required before final PASS
- Target hierarchy: Pet / calibrated Codex standard window / free-floating Halo
- Default Pet placement: automatic, with no persisted coordinates
- Optional override: every valid existing `PetRelativeAnchor` is treated as fine-tuned; only Finish persists; Cancel restores; Use Automatic Pet Placement clears only the Pet override
- Automatic position: Halo panel center equals Pet AX frame center; no activity, screen-half, distance, or available-space input can shift the panel
- Geometry boundary: `PetEnvironmentSnapshot` carries raw padded Pet frame, optional activity frame, and generation only; `PetAttachmentLayout` carries non-positional orientation, logical reference, and the center-aligned panel frame
- Displays: select the Pet's actual screen; negative X/Y and multi-display layouts are supported
- Stability: Pet movement recomputes the same center relationship; presentation transitions recompute around the Pet center; stale generations are ignored; no smooth animation
- Panel: current demo card retained / non-activating / cannot become key or main / compact click-through / expanded scrollable
- Safe menu text: Target, Pet discovery, Following, and `Pet placement: Automatic Centered` or `Fine-tuned`; no coordinates or raw AX state
- Privacy: exact `com.openai.codex` only / role, subrole, minimized, hidden, position, size only / no title, label, description, identifier, value, document content, prompt, response, screenshot, OCR, database, analytics, or telemetry
- Focused M6 validation: 76 application tests pass with fakes and synthetic geometry; no Codex process or Accessibility permission required
- Full validation: source/privacy checks, Debug build, universal arm64+x86_64 Release, 51 core tests, 89 application tests, and 14 M0 protocol tests pass
- Direct center validation: unique Pet and Halo panel were observed with equal X/Y midpoints; the 45-second movement/Tuck/Wake smoke remains pending because its latest run did not observe a Pet target
- Retained protocol boundary: M0 is PASS-CORE / PARTIAL-OPTIONALS; production remains fail-closed to CLI `0.145.0-alpha.18`; no Codex internal database dependency
- Next milestone boundary: M7 alone owns the final semicircular arc, percentage placement, semantic state colors, themes, low-usage appearance, motion preferences, and animation

M6 removes the M5 first-use calibration detour. Once Accessibility following has been explicitly enabled, a unique Pet target attaches immediately and publishes `Target: Pet`. Pet loss, Tuck Away, ambiguity, permission loss, or observer failure still preserve the M4 window anchor and use the established fallback chain. Wake or deterministic rediscovery restores the prior automatic or fine-tuned mode without user action.

Activity geometry is optional non-positional orientation metadata, not a target-selection or panel-position input. Exactly one wide nearby dialog may select an orientation for future internal Halo artwork. Zero or multiple plausible dialogs fall back to screen-region orientation. The activity frame is neither persisted nor logged, and showing or hiding the dialog cannot move the panel.

Direct user screenshots exposed that edge inference over the padded Route A Pet AX frame produced unstable side and distance results. The accepted simplification uses one invariant: panel center equals Pet AX frame center. The future M7 Halo can move its visible arc inside that transparent panel without changing the panel/Pet relationship. Fine-tune remains available as an explicit override. No pixels or screenshots enter production.

The current demo card is intentionally unchanged. M6 exposes orientation metadata so M7 can move visible arc artwork inside the center-locked transparent panel without reopening target discovery, but no final visual branding, decorative motion, particles, sound, themes, or release work is included.
