# M8 — Release UI Polish

- Branch: `m8/release-ui-polish`
- Scope: system appearance and accessibility polish, capsule contrast, visible-frame-safe label placement, Reduce Motion behavior, original icon assets, spacing, tests, smoke tooling, and current-state documentation
- Status: **PASS**
- Gate: M8 is closed; Draft PR #9 remains open and unmerged, and M9 requires separate authorization

## Outcome

M8 keeps the M7 Pet Ring and target hierarchy intact while making the existing surfaces release-facing and accessible. SwiftUI environment values now update Pet Ring capsule, track, connector, border, and shadow treatment live for light/dark appearance, Increase Contrast, Differentiate Without Color, and Reduce Transparency. Weekly, 5h, and Today retain the fixed `#5865F2`, `#00B8D9`, and `#A855F7` identity dots. Their metric keys use appearance-aware related colors with at least 4.5:1 tested contrast against the practical light and dark capsule reference backgrounds, while numeric values remain system label text. Stale and unavailable retain dashed/absent arc treatment, textual accessibility values, and visible status glyphs rather than relying on color or low opacity.

The `448×252` Pet panel, 104/94/84-point ring radii, 6-point strokes, `162`-point transparent center, persisted visual-center offset, and Pet midpoint lock are unchanged. Capsule height is normalized to 24 points with a 30-point visible-metric stack, 4-point text spacing, 6-point identity dots, a 10-point Ring gap, and fixed scale floors. The stack recenters when optional 5h or Today is omitted, so missing metrics do not leave a fixed empty row. Maximum compact K/M/B values remain one line and are covered at an accessibility text size without pixel snapshots.

## Edge-safe capsule placement

Arc opening and capsule side are separate values:

- dialog geometry continues to choose only `openingTop` or `openingBottom`;
- the selected display's `visibleFrame` chooses `.left` or `.right` for the capsule stack;
- if exactly one side fully contains every visible capsule, that side wins;
- if both sides fit, the dialog-aware side is the deterministic preference;
- an 8-point settle inset delays switching back to the preferred side only while the current side still fully fits, so hysteresis never permits clipping;
- if neither side can fit, the smaller horizontal overflow wins without moving the panel.

Selection uses global coordinates, supports negative-coordinate and multi-display layouts, stores no display identity, and runs only in `HaloPanelController` after an attachment layout already exists. It cannot affect Accessibility discovery, Pet selection, the panel center, the M4 window fallback, or free-floating placement.

## Motion policy

Normal mode retains the M7 latest-value display-linked follower and applies the newest selected Pet frame without overshoot or queued `NSWindow` animation. Reduce Motion now uses a direct path before a display link can start. If the system setting changes while a normal follow is active, the next display refresh applies the newest frame directly and invalidates the display-link callback. Returning to normal motion allows the next continuous move to create a fresh display link. The preference is read live, never persisted, and cannot affect discovery, orientation, placement geometry, or fallback.

## Original icon system

The AppIcon is an original abstract three-ring Halo mark rendered by the repository's Core Graphics generator at all required macOS sizes from 16 through 1024 pixels. It uses no Codex Pet, OpenAI, or ChatGPT artwork, copied asset, third-party font, or third-party library. A separate two-scale monochrome mark carries the same concentric-ring identity for the menu bar and is compiled with template-rendering intent. The menu does not reuse the full-color AppIcon and no longer uses the generic `circle.dashed` SF Symbol.

## Boundaries

M8 adds no theme system, user-selectable palette, decorative motion, particles, glow, sound, packaging, signing, notarization, GitHub Release automation, protocol method, credential access, database access, analytics, telemetry, network request, Screen Recording, screenshot/OCR, or visual target detection. Pet discovery, Usage semantics, component freshness, target hierarchy, panel centering, bridge behavior, and fallback architecture are unchanged.

## Verification matrix

| Gate | Current result |
| --- | --- |
| Appearance, contrast, edge placement, Reduce Motion, optional metrics, large text, and existing M0–M7 behavior | PASS — 105 focused Swift tests plus 2 asset checks |
| AppIcon catalog and template menu icon | PASS — deterministic catalog, PNG dimension/alpha, source configuration, and compiled-bundle checks |
| Full regression, Debug, and universal Release bundle | PASS — `make check`; 51 Core tests with 1 designed local-only skip, 116 App tests, 16 Python tests, and `arm64+x86_64` Release |
| M2–M7 retained smoke | PASS — authenticated bridge/lifecycle, window-following discovery, independent Pet movement, center lock, default hide, Wake recovery, non-activation, Quit, observer, and owned-child cleanup |
| M8 visual/accessibility smoke | PASS — deterministic policy/bundle checks plus direct observer acceptance |
| Direct appearance and edge matrix | PASS — light/dark, Increase Contrast, Reduce Motion, left/right screen edges, menu icon, Finder/Get Info icon, Pet movement, Tuck Away default hide, Wake, and Quit |
| Optional data matrix | PASS — current Today-present/5h-absent state observed directly; other supported omission/presence combinations covered deterministically without synthesizing data |
| Draft PR CI | PASS — Protocol evidence and macOS application jobs both passed on PR #9 |

M9 — Public Beta Release Readiness is the next milestone. It is not authorized by completion of M8.
