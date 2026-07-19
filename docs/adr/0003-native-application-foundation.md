# ADR 0003: Use a generated native macOS accessory application foundation

- Status: Accepted
- Date: 2026-07-20

## Context

M1 needs a reproducible native application shell and clean seams for later milestones without implementing future protocol, Usage, Halo, or window-tracking behavior. The repository began as Python-only M0 evidence and had no Xcode project.

The project considered a hand-maintained Xcode project, Swift Package Manager alone, and XcodeGen. A hand-maintained project makes structural changes difficult to review. Swift Package Manager does not by itself describe a macOS application bundle, Info.plist, accessory behavior, or hosted unit-test target. XcodeGen provides a reviewable declarative source while still producing a standard Xcode project.

## Decision

- Use Swift 6 with strict concurrency checking and Apple frameworks only.
- Use SwiftUI for the `MenuBarExtra` scene and AppKit for application-delegate and termination lifecycle ownership.
- Target macOS 14.0 because `MenuBarExtra` is mature there and M1 has no evidenced need for a newer API.
- Use XcodeGen 2.46.0 with `project.yml` as the editable source of truth.
- Commit the generated `PetHalo.xcodeproj` so a checkout is inspectable in Xcode; CI regenerates it with the pinned tool and fails on drift.
- Create one application target, `PetHalo`, and one hosted unit-test target, `PetHaloTests`. Do not create empty future framework targets.
- Configure the app as an accessory application with `LSUIElement` and an AppKit accessory activation policy. It has no normal window or Dock icon.
- Keep explicit coordinator start, termination-request, and stopped states. The coordinator is the future ownership boundary, but it does not contain or name speculative CodexBridge or Halo controllers.

## Deferred decisions

M1 does not enable App Sandbox. A later architecture milestone must evaluate sandboxing against the accepted future owned stdio child process and supported window observation before adding entitlements.

Signing, notarization, packaging, updating, and distribution are also deferred. Local and CI validation disable code signing and require no Apple account or secret.

## Consequences

Project changes are reproducible and reviewable, but contributors must use the pinned XcodeGen version and regenerate rather than edit the project file. The application provides a real lifecycle and menu shell while preserving the boundary that JSON-RPC, Usage, Halo UI, `NSPanel`, permissions, and Codex observation belong to later milestones.
