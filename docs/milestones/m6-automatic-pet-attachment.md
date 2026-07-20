# M6 Automatic Pet Attachment & Adaptive Placement

- Branch: `m6/automatic-pet-attachment`
- Scope: automatic first-use Pet attachment, fixed Pet/Halo center alignment, optional non-positional orientation metadata, optional fine-tuning, tests, smoke, privacy, and documentation
- Stop condition: Draft PR; do not merge and do not begin M7

## Outcome

M6 removes the first-use Pet calibration requirement. A uniquely discovered Pet attaches immediately without a saved Pet anchor, does not publish Calibration Required, and remains preferred over the preserved M4 calibrated Codex-window and M3 free-floating fallbacks.

Placement has two explicit modes. No Pet anchor means automatic. Every valid pre-M6 Pet anchor migrates without data loss as a fine-tuned override. Fine-tuning persists only after Finish; Cancel restores the prior automatic/manual state and reference; Use Automatic Pet Placement removes only the Pet override and never the M4 window anchor.

## Center-lock policy

`PetEnvironmentSnapshot` contains only the raw padded Pet frame, an optional activity frame, and a generation. Direct user screenshots showed that attempting to infer the rendered head/feet edge from the padded Route A surface produced inconsistent sides and distances. The accepted policy is deliberately smaller: automatic layout makes the Halo panel midpoint equal the raw Pet frame midpoint. This relationship is identical in every screen region, with or without an activity dialog, and at display edges. Fine-tune remains the explicit manual override.

The pure layout policy applies this invariant:

1. `panel.midX == pet.midX`;
2. `panel.midY == pet.midY`;
3. Pet movement or panel-size changes recompute the panel around the same Pet midpoint;
4. activity, screen half, available space, and display edges cannot shift that midpoint.

The policy supports negative display coordinates and never uses `NSScreen.main` to place the panel. Activity/screen logic remains only as orientation metadata for future artwork inside the transparent panel. Fine-tuning retains its manual anchor behavior, stale generations are ignored, and M6 adds no smooth animation.

## Presentation and lifecycle

`PetAttachmentLayout` exposes side, logical reference point, and complete panel frame through the presentation boundary. The current demo card remains. Compact stays click-through, expanded stays scrollable, the `NSPanel` remains non-activating and ineligible for key/main status, and shutdown still stops observers before panel and app-server teardown.

Menu terminology is Fine-tune Pet Position and Use Automatic Pet Placement. Status is limited to Automatic Centered, Fine-tuned, or Unavailable; coordinates and raw AX state are not exposed.

## Validation status

| Gate | Result |
| --- | --- |
| `make m6-tests` | PASS — 76 focused application tests |
| First-use automatic attachment / no Calibration Required | PASS — deterministic |
| Center equality / movement / panel-size changes / negative displays | PASS — deterministic |
| Activity and screen geometry cannot shift panel center | PASS — deterministic |
| Tuck Away / Wake / manual override / Cancel / Reset | PASS — deterministic |
| Compact/expanded / non-activation / observer shutdown | PASS — deterministic |
| User-requested fixed Pet/Halo center relationship | PASS — directly observed on current Head |
| `make check` and M0-M5 regression | PASS — source/privacy, Debug, universal Release, 51 core, 89 app, and 14 M0 tests |
| Direct Pet/Halo midpoint equality | PASS — sanitized live AX geometry on current Head |
| `make m6-smoke` movement / Tuck Away / Wake | BLOCKED — latest 45-second run did not observe a Pet target; retry required |
| `make m2-smoke` through `make m5-smoke` | Pending current Head |
| Direct independent Pet movement and interaction | Pending current Head |
| Draft PR CI and independent review | Pending current Head |

M6 is not final PASS until the pending rows pass. Sanitized smoke output contains no coordinates, PIDs, titles, identifiers, Usage values, or account data.

## Explicit non-goals

M7 owns the final semicircular arc, percentage placement, semantic state colors, visual themes, low-usage appearance, motion preferences, and animation. M6 adds no final branding, decorative motion, particles, sound, Screen Recording, visual detection, screenshots, OCR, packaging, or release work.
