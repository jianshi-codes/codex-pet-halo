# ADR 0010: Release visual accessibility

- Status: Accepted for M8
- Date: 2026-07-21

## Context

M7 establishes functional concentric rings, fixed semantic colors, fixed identity dots, a dialog-aware arc opening, and an exact center-locked Pet attachment. Its capsule side mirrors with the arc opening, which can clip labels at a display edge even though the Ring center itself is correct. The initial capsule tint is also not a sufficient text color on every system appearance, especially cyan in light appearance. The app still uses a generic menu-bar symbol and has no complete AppIcon catalog.

Release-facing polish must work with macOS appearance and accessibility settings without introducing themes, moving the Pet/Ring center, changing target discovery, or replacing the normal M7 follower.

## Decision

Keep all M7 geometry and semantic inputs, then add three presentation-only policies.

1. `PetRingAppearancePolicy` derives opacity, border, track, connector, and shadow treatment from live SwiftUI appearance, Increase Contrast, and Reduce Transparency environment values. Fixed system semantic colors remain status-driven. Identity dots keep the exact M7 palette; appearance-aware related key-text colors meet a deterministic 4.5:1 practical contrast floor. Numeric values stay in system label color. Stale/unavailable states use shape, glyph, text, and accessibility semantics rather than opacity alone. Differentiate Without Color adds a compact semantic glyph.
2. `PetRingLabelPlacementPolicy` receives the already-computed panel frame, selected display `visibleFrame`, visible metrics, dialog-preferred side, and current side. It chooses only the label side. It never returns a panel frame or reference point. One-sided full containment wins; both-fit uses the preferred side with a small no-clipping settle inset; neither-fit minimizes overflow. Global Core Graphics coordinates naturally cover negative and multi-display layouts, and screen identity is not persisted.
3. `PetFrameFollower` checks Reduce Motion before starting a display link and again on each active callback. Reduce Motion applies the newest layout directly and invalidates the callback. Normal mode preserves the latest-value display-linked behavior. No animation queue or decorative motion is introduced.

The app and menu icons share one original abstract concentric-ring identity but remain separate assets. AppIcon is a full-color macOS catalog generated with repository-owned Core Graphics code. MenuBarIcon is a monochrome 1x/2x template imageset. Neither is derived from official artwork.

## Consequences

System appearance changes render live through SwiftUI and dynamic system colors. Labels stay inside the selected visible frame whenever either side can fully contain them, while the Ring/Pet center remains untouched. Optional metrics collapse into an evenly spaced stack. Reduce Motion performs no interpolation and does not leave an active display-link callback.

The implementation adds a small deterministic policy surface and tests instead of pixel snapshots or a theme abstraction. It does not add packaging, signing, notarization, decorative animation, sound, glow, particles, screenshots/OCR, Screen Recording, visual target detection, new persistence, or protocol behavior. M9 remains separately gated.
