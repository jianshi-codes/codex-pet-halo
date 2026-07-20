# ADR 0008: Unconditional Center-Locked Pet Attachment

- Status: Accepted for M6
- Decision: always align the Halo panel midpoint with the selected Pet AX frame midpoint

## Context

M5 proved a unique geometric Pet target but required a saved Pet-relative anchor before following could begin. Direct screenshots then showed that inferring rendered head/feet edges from the padded AX frame produced inconsistent side and distance results. M7's planned ring has a transparent center, so the panel itself does not need an above/below offset.

## Decision

Whenever Pet is the selected target, placement computes the panel frame directly around the Pet midpoint. There is no manual Pet placement mode and no positional override. Startup idempotently deletes the legacy `io.github.jianshicodes.PetHalo.petFollowing.anchor.v1` preference while leaving the M4 Codex-window anchor unchanged.

The fine-tune API remains as a compatibility hook for existing callers, but its Pet-positioning implementation is intentionally inert. It creates no calibration session, writes no preference, and cannot change the center-lock invariant. User-facing Fine-tune and Reset-to-Automatic commands are removed.

The Accessibility boundary returns `PetTargetSnapshot(frame, generation)`. The automatic layout needs no screen lookup, activity dialog, above/below side, fit decision, visible-frame clamp, orientation, or hysteresis. `PetAttachmentLayout` contains only the logical center reference and centered panel frame. Pet movement, Pet resize, and panel-size changes recompute from the current Pet midpoint; stale generations are rejected.

Until M7 replaces the demo card, Pet targeting forces Compact and rejects Expanded commands. Leaving Pet restores the previous fallback card mode and normal mode controls.

## Consequences

First use attaches immediately, old Pet anchors cannot displace the panel, and Wake recovers without user action. M4/M3 fallback and M4 calibration remain intact. Pet discovery observes only selected Pet core surfaces and application window creation needed for recreation.

The center relationship is stable across activity-dialog changes, screen regions, display edges, and negative coordinates. Future artwork may move inside the transparent panel without changing target discovery or panel placement.

## Rejected alternatives

- Preserving legacy Pet anchor offsets: violates unconditional center lock and keeps unstable per-user state.
- Activity-relative or screen-half placement: reintroduces the wrong-side and excessive-distance behavior exposed by direct screenshots.
- Persisting automatic coordinates: becomes stale across Pet movement and is unnecessary.
- Using `NSScreen.main`: incorrect for other or negative-coordinate displays and unnecessary for midpoint alignment.
- Replacing the M4 anchor: destroys the permanent fallback and violates the target hierarchy.
- Adding ring artwork or animation: belongs to M7 or M8, not M6.
