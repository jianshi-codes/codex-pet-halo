# Contributing

M0 through M5 are complete. M5 follows the independently movable Pet through a discovery-proven Route A AX window, with M4 calibrated Codex-window following and M3 free-floating placement preserved as fallbacks. Contributions must remain within the completed M5 boundary until a later milestone receives separate authorization.

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
10. Pet selection must remain deterministic and fail closed: one near-square `AXWindow/AXDialog` logical frame after overlap collapse, otherwise use M4/M3 fallback. Never use array order or activity-dialog placement.
11. Do not add screenshots, ScreenCaptureKit, OCR, visual recognition, Apple Events, private IPC, automatic attachment, adaptive placement, final artwork, animation, themes, or later milestone behavior during M5.
12. M6 owns automatic first-use Pet attachment and adaptive above/below placement; M7 owns the final semicircular Halo, percentage label, semantic status treatment, themes, and motion; M8 owns compatibility, packaging, privacy audit, and release readiness. None is authorized by M5 completion.

## Validation

```sh
make check
```

Use `make m5-tests` for deterministic Pet/window selection, geometry, separate anchors, hierarchy, fallback/recovery, observer, panel, and coordinator coverage. `make m2-smoke`, `make m3-smoke`, `make m4-smoke`, and `make m5-smoke` are local-only checks and print sanitized status.

Describe the Codex CLI version used to generate schemas and redact all captured protocol fixtures before committing them.
