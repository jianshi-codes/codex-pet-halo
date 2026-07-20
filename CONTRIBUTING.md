# Contributing

M0 through M7 are complete. M7 presents the independently movable Pet with a calibrated, transparent concentric-ring surface while preserving M4 calibrated Codex-window following and M3 free-floating placement as fallbacks. M8 — Visual Polish, Themes & Motion — is next but has not started. Contributions must stay within the explicitly authorized milestone.

## Development rules

1. Keep changes small and milestone-scoped.
2. Never copy credentials, authentication headers, full account records, thread content, local absolute paths, or unsanitized app-server payloads into the repository.
3. Treat `project.yml` as the Xcode project source of truth. Use XcodeGen 2.46.0 and do not hand-edit the generated project.
4. Generate protocol bindings from the locally installed Codex CLI. Do not hand-edit generated schema files.
5. Keep all protocol work read-only: do not call `thread/start`, `turn/start`, account mutation, or any other mutation method.
6. Do not make production Swift code depend on the M0 probe, schemas, or fixtures.
7. Do not read or depend on Codex internal SQLite databases.
8. Keep the Halo non-activating, compact click-through, account-identity-free, and driven by component freshness rather than aggregate timestamps.
9. Accessibility access is restricted to the exact Codex bundle and reviewed window role/subrole, minimized/hidden, position, and size attributes plus lifecycle/geometry notifications. Never inspect titles, labels, descriptions, identifiers, values, document text, prompts, or responses.
10. Pet selection must remain deterministic and fail closed: prefer one stable near-square `AXWindow/AXSystemDialog` logical frame after overlap collapse, retain near-square `AXDialog` only as a compatibility fallback, otherwise use M4/M3 fallback. Activity geometry may affect only ring and capsule orientation after Pet selection; it must never affect placement or discovery.
11. Pet placement must retain the raw AX Pet midpoint as its tracking basis and apply only the persisted fixed `PetVisualCenterOffset` to the complete Ring surface. The legacy normalized Pet anchor stays deleted; the M4 Codex-window anchor remains separate and intact.
12. Do not add screenshots, ScreenCaptureKit, OCR, visual recognition, Apple Events, private IPC, final artwork, animation, themes, sound, particles, packaging, or later-milestone behavior without separate authorization.
13. M7 owns the functional Pet ring, fixed arc/orientation policy, capsule labels, and basic Usage metrics. M8 owns advanced styling beyond that policy, themes, low-usage visuals, and decorative motion. M9 owns compatibility hardening, privacy audit, packaging, and release readiness.

## Validation

```sh
make check
```

Use `make m7-tests` for deterministic Pet/window selection, visual-center persistence, Ring geometry and semantics, capsule layout, orientation, latest-value following, hierarchy, fallback/recovery, observer, panel, and coordinator coverage. `make m2-smoke` through `make m7-smoke` are local-only checks and print sanitized status.

Describe the Codex CLI version used to generate schemas and redact all captured protocol fixtures before committing them.
