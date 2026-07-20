# Contributing

M0 through M6 are implemented. M6 automatically attaches to the independently movable Pet through the discovery-proven Route A AX window and locks the Halo panel center to the Pet center. M4 calibrated Codex-window following and M3 free-floating placement remain permanent fallbacks. Contributions must stay within the M6 boundary until a later milestone receives separate authorization.

## Development rules

1. Keep changes small and milestone-scoped.
2. Never copy credentials, authentication headers, full account records, thread content, local absolute paths, or unsanitized app-server payloads into the repository.
3. Treat `project.yml` as the Xcode project source of truth. Use XcodeGen 2.46.0 and do not hand-edit the generated project.
4. Generate protocol bindings from the locally installed Codex CLI. Do not hand-edit generated schema files.
5. Keep all protocol work read-only: do not call `thread/start`, `turn/start`, account mutation, or any other mutation method.
6. Do not make production Swift code depend on the M0 probe, schemas, or fixtures.
7. Do not read or depend on Codex internal SQLite databases.
8. Keep the Halo non-activating, compact click-through outside calibration, account-identity-free, and driven by component freshness rather than aggregate timestamps.
9. Accessibility access is restricted to the exact Codex bundle and reviewed window role/subrole, minimized/hidden, position, and size attributes plus lifecycle/geometry notifications. Never inspect titles, labels, descriptions, identifiers, values, document text, prompts, or responses.
10. Pet selection must remain deterministic and fail closed: one near-square `AXWindow/AXDialog` logical frame after overlap collapse, otherwise use M4/M3 fallback. Activity geometry may influence side only when exactly one wide nearby dialog is selected; ambiguity removes the hint without invalidating Pet.
11. Keep automatic placement coordinate-free in persistence. Existing valid Pet anchors are manual overrides, Finish is the only persistence point, Cancel restores the prior mode, and Use Automatic Pet Placement must preserve the M4 anchor.
12. Do not add screenshots, ScreenCaptureKit, OCR, visual recognition, Apple Events, private IPC, final artwork, animation, themes, sound, particles, packaging, or later milestone behavior during M6.
13. M7 owns the final semicircular arc, percentage placement, semantic state colors, visual themes, low-usage appearance, motion preferences, and animation. M8 owns compatibility hardening, packaging, privacy audit, and release readiness.

## Validation

```sh
make check
```

Use `make m6-tests` for deterministic Pet/window selection, adaptive geometry, separate anchors, hierarchy, fallback/recovery, hysteresis, observer, panel, and coordinator coverage. `make m2-smoke` through `make m6-smoke` are local-only checks and print sanitized status.

Describe the Codex CLI version used to generate schemas and redact all captured protocol fixtures before committing them.
