# ADR 0007: Pet Target Discovery and Relative Following

- Status: Accepted for M5
- Decision: `ROUTE_A — PET_ACCESSIBILITY_WINDOW`

## Context

M4 follows a calibrated point relative to the standard Codex window. The independently movable Codex Pet is a different target. M5 was discovery-gated because neither an Accessibility window nor a descendant element could be assumed.

Local read-only validation demonstrated one logical near-square `AXWindow/AXDialog` frame that moves with Pet independently of the standard Codex window. Wide activity UI and `AXSystemDialog` controls also move, change layout, and can appear or disappear. Two overlapping core layers can briefly become non-coincident during movement.

## Decision

Production uses a Pet target accessor confined to the exact selected `com.openai.codex` process. It reads the application window list and only role, subrole, minimized, hidden, position, and size attributes. It observes created, moved, resized, and destroyed notifications. No AX object, process identifier, title, identifier, raw error, or coordinate reaches the presentation layer.

The target priority is:

1. a uniquely resolved Pet target with a valid Pet-relative anchor;
2. the existing M4 calibrated standard-window anchor;
3. the existing M3 free-floating position.

The Pet selector requires exactly one logical near-square `AXWindow/AXDialog` frame after half-point overlap collapse. Zero matches are unavailable; multiple logical frames are ambiguous. It never uses array order, titles, identifiers, activity-dialog position, or button count.

Geometry notifications are coalesced for 80 ms. If overlapping layers are temporarily non-atomic, the service rechecks at 160 ms. Persistent ambiguity is never guessed: the service preserves the Pet anchor and switches to M4 or free-floating. A five-second recovery task attempts deterministic Pet rediscovery while a fallback is active, avoiding rapid target oscillation.

## Persistence

M5 adds `io.github.jianshicodes.PetHalo.petFollowing.anchor.v1`, containing only:

- `version`;
- normalized Pet point `x/y`;
- point offset `width/height`.

It is separate from the M4 window anchor. Invalid versions, non-finite values, out-of-range normalized values, and offsets over 10,000 points are rejected. Reset Pet Position clears only the Pet anchor. No PID, AX identity, frame snapshot, title, screen index, account data, or Usage value is stored.

## Consequences

Pet-relative following can resume after Pet recreation without recalibration. Pet loss, ambiguity, observer failure, permission loss, and Codex restart remain safe because the existing M4 and M3 fallbacks are preserved. Explicit window-fallback calibration does not suppress the preferred Pet target after calibration completes.

The Route A surface is undocumented and Codex-version-sensitive. The official [Codex Pets documentation](https://learn.chatgpt.com/docs/pets.md) describes user-facing Pet behavior but does not promise an AX hierarchy. Compatibility changes therefore degrade to fallback rather than broadening inspection.

## Rejected alternatives

- Route B descendant following: bounded traversal did not find a structural element that moved with Pet.
- Title, label, description, identifier, or array-order selection: either content-bearing, unstable, unnecessary, or non-deterministic.
- Vertical relationship to the activity dialog: the dialog changes sides based on placement.
- ScreenCaptureKit, screenshots, OCR, or visual recognition: unnecessary for the proven Route A and outside M5 authorization.
- Reusing the M4 anchor: conflates independent coordinate systems and would destroy the permanent fallback.
