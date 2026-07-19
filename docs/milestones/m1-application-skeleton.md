# M1 Application Skeleton

- Status: **PASS**
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
| Generator release digest | SHA-256 `4d9e34b62172d645eed6457cac13fc222569974098ef4ee9c3368bedf0196806` |
| Generated project | Committed; `make check` regenerates and checks tracked and untracked project drift |
| Sandbox/signing | Deferred; command-line and CI builds disable signing |

The committed project supports direct Xcode inspection, while the declarative source prevents hand-edited project-file drift. `make bootstrap` validates prerequisites but installs nothing. CI pins the checkout action by commit, disables persisted Git credentials, downloads the pinned upstream XcodeGen release with bounded retries and timeouts, and verifies its SHA-256 before extraction.

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
| Release universal application build and bundle assertion | PASS, `arm64` and `x86_64` |
| Swift unit tests | PASS, 5 tests |
| Retained M0 unit/fixture tests | PASS, 14 tests |
| Python compile validation | PASS |
| Debug and Release Info.plist validation | PASS |
| Bundle schema/fixture exclusion | PASS |
| Production dependency/capability boundary scan | PASS |
| Credential, email, and user-path scan | PASS |
| Generated project tracked/untracked drift check | PASS |
| Draft PR CI | PASS, protocol evidence and macOS application jobs |

The Swift tests cover initial lifecycle state, idempotent start and shutdown transitions, single termination dispatch, version/build formatting, missing metadata behavior, and the menu model. Shell validation checks bundle identifier, version, build, `LSUIElement`, macOS 14.0, both required Release executable architectures in either order, forbidden production dependencies, sensitive permissions, M0 resource leakage, and generated-project drift including untracked files.

## Manual smoke test

The Debug application was launched with macOS Launch Services and remained running. Read-only AppKit/CoreGraphics inspection reported accessory activation policy (`NSApplication.ActivationPolicy.accessory`) and zero windows owned by the process; accessory policy excludes a normal Dock presence. A standard macOS application termination request was accepted and the process exited.

The operator then opened the real menu-bar item, selected `Quit Pet Halo`, and confirmed that the application closed without issue. This completes the direct UI observation separately from the automated coordinator tests.

## Explicit non-goals preserved

M1 introduces no JSON-RPC transport, app-server child process, account/Usage/Context model, polling or reconnection, `NSPanel`, Halo or Usage UI, process/window detection, permissions, positioning, animation, final branding, updater, signing, notarization, packaging, analytics, telemetry, network service, or later milestone placeholder target.

## M0 preservation and privacy

M0 remains **PASS-CORE / PARTIAL-OPTIONALS**. No file under `Tools/ProtocolProbe/Schemas/` or `Tests/Fixtures/CodexProtocol/` is intentionally changed by M1. The Python probe is not a runtime dependency or application resource.

The M1 application shell reads and stores no Codex data. Lifecycle logging uses fixed messages only and never includes paths, environment variables, process output, account information, or user data.

## Gate

The local automated checks, Draft PR CI, and manual menu/Quit smoke test pass. The M1 gate is **PASS**. The exact next recommended milestone is a separately authorized **M2 — CodexBridge**; M1 does not authorize or start it.
