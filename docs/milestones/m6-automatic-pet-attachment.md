# M6 Automatic Center-Locked Pet Attachment

- Branch: `m6/automatic-pet-attachment`
- Scope: automatic first-use Pet attachment, unconditional Pet/Halo center lock, preserved fallback/lifecycle, temporary Compact guard, tests, smoke, privacy, and documentation
- Stop condition: Draft PR; do not merge and do not begin M7

## Outcome

M6 removes the first-use Pet calibration requirement. A uniquely discovered Pet attaches immediately without a saved Pet anchor, does not publish Calibration Required, and remains preferred over the preserved M4 calibrated Codex-window and M3 free-floating fallbacks.

Pet positioning has one production behavior: centered. Startup safely removes the legacy M5 Pet-anchor preference so an old normalized offset cannot move the panel. This migration does not read, rewrite, or delete the separate M4 Codex-window anchor. The fine-tune API remains as a source-compatible hook, but calling it cannot create Pet calibration state, persist a Pet anchor, or change the centered layout.

## Center-lock policy

`PetTargetSnapshot` contains only the raw padded Pet frame and generation. The pure layout policy applies one invariant:

1. `panelFrame.midX == petFrame.midX`;
2. `panelFrame.midY == petFrame.midY`;
3. Pet movement, Pet resize, and panel-size changes recompute around the same midpoint;
4. screen geometry, display half, activity dialogs, available space, and orientation are not inputs.

The policy supports negative global coordinates without looking up `NSScreen.main` or any other screen. Stale target generations remain ignored. The Pet accessor observes only selected Pet core surfaces plus application window creation needed for Pet recreation.

## Presentation and lifecycle

`PetAttachmentLayout` exposes only a logical reference point and complete panel frame. Pet targeting temporarily forces the existing demo surface to Compact and rejects direct Expanded commands. When Pet is lost or another target becomes active, the coordinator restores the previous fallback card mode and normal Compact/Expanded controls.

The panel remains non-activating and cannot become key or main. Compact remains click-through. Tuck Away falls back through M4/M3, Wake returns to centered Pet placement, and shutdown still stops observers before panel and owned app-server teardown.

Safe placement status is limited to Centered or Unavailable. No coordinates, side, activity relationship, raw AX state, or legacy anchor state is exposed.

## Validation status

| Gate | Result |
| --- | --- |
| `make m6-tests` | PASS — 58 focused application tests |
| No saved Pet anchor → centered | PASS — deterministic |
| Legacy Pet anchor removed / M4 anchor preserved | PASS — deterministic and real `UserDefaults` migration coverage |
| Movement / resize / panel-size changes / negative coordinates | PASS — deterministic exact midpoint equality |
| Activity-window creation cannot change placement | PASS — deterministic |
| Fine-tune API cannot override center lock | PASS — deterministic |
| Pet forces Compact / Expanded rejected / fallback mode restored | PASS — deterministic |
| Tuck Away / Wake / fallback and recovery | PASS — deterministic |
| Observer and service shutdown | PASS — deterministic |
| Repeated M2 refresh-coalescing test | PASS — 30/30 fail-fast repetitions without retry |
| `make check` | PASS — source/privacy, Debug, universal arm64+x86_64 Release, 121 Swift passes + 1 designed local-only skip, 14 M0 passes |
| `make m2-smoke` through `make m5-smoke` | PASS — current Head |
| Direct M6 movement / fallback / Wake / Quit | PASS — sanitized observer captured every required transition and cleanup; user confirmed visual behavior |
| Corrected M6 center-lock smoke harness | READY — typechecked after removing a non-contract pre-movement ordering assertion; the direct live evidence above satisfied the interaction gate |
| Draft PR CI and independent review | Pending current Head |

M6 is not final PASS until Draft PR CI and independent review pass. Sanitized smoke output contains no coordinates, PIDs, titles, identifiers, Usage values, or account data.

## Explicit non-goals

M7 owns the functional Pet ring and basic Usage metrics. M8 owns advanced styling, arc orientation, themes, low-usage visuals, motion preferences, and animation. M9 owns compatibility hardening, privacy audit, packaging, and release readiness. M6 adds no final branding, decorative motion, particles, sound, Screen Recording, visual detection, screenshots, OCR, packaging, or release work.
