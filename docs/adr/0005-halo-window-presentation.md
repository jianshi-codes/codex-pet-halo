# ADR 0005: Present Usage through one owned non-activating Halo panel

- Status: Accepted
- Date: 2026-07-20

## Context

M2 provides stable capability and component-freshness state but deliberately has no quota UI. M3 needs an ambient surface that remains visible without creating a normal application window, taking keyboard focus, intercepting Codex input, or coupling presentation to protocol DTOs. M3 must also stop before discovering or following Codex windows and before final visual design.

## Decision

- Use one dedicated borderless `NSPanel` with `.nonactivatingPanel`, `canBecomeKey` and `canBecomeMain` both false, clear non-opaque backing, floating level, all-Spaces/full-screen auxiliary behavior, and normal window cycling disabled.
- `ApplicationCoordinator` owns the panel controller and remains the only consumer of `CodexUsageServing.states()`. It publishes the latest full domain state, maps it once, and updates the panel on the main actor. The panel never subscribes to the bridge.
- Keep panel creation, show/hide, resizing, and shutdown in `HaloPanelController`. Repeated commands are idempotent. Shutdown closes the panel and releases its hosted content before awaiting bridge shutdown.
- Keep compact and expanded modes in one hosting view and one panel. Compact shows the weekly remaining gauge plus an optional real five-hour value. Expanded adds reset details and present Account Usage fields, with recent days explicitly sorted and limited to seven.
- Compact is click-through. Expanded accepts pointer and scroll events so its bounded content is reachable, while the panel remains `.nonactivatingPanel` and cannot become key or main. Both modes are controlled from the menu bar; mode transitions alone change the mouse-event policy.
- Map weekly and five-hour state from rate-limit component freshness and Account Usage from its independent component freshness. Retained stale values remain visible with text saying `Stale`; unavailable values never receive fabricated percentages or zeros. Context and account identity do not enter the presentation model.
- Format visible reset text in the user's locale/time zone with an injected clock, and expose a stable absolute accessibility value. Centralize deterministic accessibility strings, hide decorative gauge elements from accessibility, use textual current/stale/unavailable states, and honor Reduce Transparency and Differentiate Without Color.
- Place the initial frame once in the upper-right of an available screen's visible frame with a fixed inset and containment. Do not inspect Codex, persist a frame, or move automatically.
- Use neutral system materials, colors, and text styles without artwork or decorative motion.

## Deferred decisions

M4 owns Codex/Pet discovery decisions, explicit calibration, relative anchoring, multi-display following, and any free-floating persistence. M5 owns original mascot/artwork, final colors, themes, and game-like motion. Neither is required for M3 correctness.

## Consequences

The Halo is a small accessory surface rather than a settings window, and Usage semantics remain deterministic and testable without AppKit. Expanded scrolling is available without adding activation, keyboard focus, drag, or persistence behavior. The fixed upper-right position is intentionally temporary and must not be described as relative to Codex Pet.
