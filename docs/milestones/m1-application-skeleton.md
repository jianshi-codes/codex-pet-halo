# M1 Application Skeleton

- Status: **IMPLEMENTED LOCALLY — MANUAL MENU CLICK AND CI PENDING**
- Date: 2026-07-20
- Scope: native macOS accessory application, lifecycle boundary, menu-bar shell, unit tests, reproducible build commands, CI, and documentation
- Stop condition: Draft M1 PR complete; do not implement M2 CodexBridge or M3 Halo UI

## Implemented behavior

Pet Halo is a Swift 6 macOS application with a SwiftUI `MenuBarExtra` and AppKit lifecycle delegate/coordinator. It is configured with `LSUIElement`, uses a neutral system symbol, identifies itself as Pet Halo, displays `Application skeleton` plus version/build metadata, and exposes a Quit action.

The application opens no normal window and contains no Halo overlay. It does not launch Codex or an app-server, read account or Usage data, inspect processes/windows, request permissions, use the network, or store user data.

## Architecture and project generation

| Decision | Result |
| --- | --- |
| Native stack | Swift 6, SwiftUI, and AppKit interoperability |
| Deployment target | macOS 14.0 |
| Runtime dependencies | Apple frameworks only |
| Targets | `PetHalo` application and `PetHaloTests` hosted unit tests |
| Lifecycle boundary | `ApplicationCoordinator` owned by `AppDelegate`, isolated to `@MainActor` |
| Project source | `project.yml` |
| Generator | XcodeGen 2.46.0 |
| Generated project | Committed; CI regenerates and checks for drift |
| Sandbox/signing | Deferred; command-line and CI builds disable signing |

The committed project supports direct Xcode inspection, while the declarative source prevents hand-edited project-file drift. `make bootstrap` validates prerequisites but installs nothing. CI downloads the pinned upstream XcodeGen release.

## Command surface

```sh
make bootstrap
make generate
make build
make test
make m0-tests
make check
```

Build products and test results are written under ignored `DerivedData` paths. Production targets do not reference `Tools/ProtocolProbe`, generated schemas, or M0 fixtures.

## Automated evidence

| Check | Result |
| --- | --- |
| XcodeGen 2.46.0 generation | PASS |
| Debug application build | PASS |
| Release universal application build | PASS |
| Swift unit tests | PASS, 5 tests |
| Retained M0 unit/fixture tests | PASS, 14 tests |
| Python compile validation | PASS |
| Debug and Release Info.plist validation | PASS |
| Bundle schema/fixture exclusion | PASS |
| Production dependency/capability boundary scan | PASS |
| Credential, email, and user-path scan | PASS |
| Draft PR CI | PENDING |

The Swift tests cover initial lifecycle state, idempotent start and shutdown transitions, single termination dispatch, version/build formatting, missing metadata behavior, and the menu model. Shell validation checks bundle identifier, version, build, `LSUIElement`, macOS 14.0, forbidden production dependencies, sensitive permissions, and M0 resource leakage.

## Manual smoke test

The Debug application was launched with macOS Launch Services and remained running. Read-only AppKit/CoreGraphics inspection reported accessory activation policy (`NSApplication.ActivationPolicy.accessory`) and zero windows owned by the process; accessory policy excludes a normal Dock presence. A standard macOS application termination request was accepted and the process exited.

The available Computer Use interface could not attach to this windowless `LSUIElement` process, and the helper accessibility tree likewise did not expose the status item. Therefore the menu contents and a direct click on `Quit Pet Halo` were **not manually observed**. The compiled menu model and coordinator tests prove the command wiring and single termination dispatch, but they are not presented as a substitute for the missing direct UI observation.

## Explicit non-goals preserved

M1 introduces no JSON-RPC transport, app-server child process, account/Usage/Context model, polling or reconnection, `NSPanel`, Halo or Usage UI, process/window detection, permissions, positioning, animation, final branding, updater, signing, notarization, packaging, analytics, telemetry, network service, or later milestone placeholder target.

## M0 preservation and privacy

M0 remains **PASS-CORE / PARTIAL-OPTIONALS**. No file under `Tools/ProtocolProbe/Schemas/` or `Tests/Fixtures/CodexProtocol/` is intentionally changed by M1. The Python probe is not a runtime dependency or application resource.

The M1 application shell reads and stores no Codex data. Lifecycle logging uses fixed messages only and never includes paths, environment variables, process output, account information, or user data.

## Gate

The local automated portion of the M1 gate passes. Final state remains pending until a direct menu/Quit smoke observation and Draft PR CI complete. The next recommended milestone after an M1 PASS is a separately authorized **M2 — CodexBridge**; M1 does not authorize it.
