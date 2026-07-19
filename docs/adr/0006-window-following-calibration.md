# ADR 0006: Explicit calibrated Codex window following

- Status: Accepted for M4
- Date: 2026-07-20

## Decision

Pet Halo remains useful as a free-floating non-activating panel. Window following is an explicit opt-in enhancement. Startup loads validated UI preferences and checks Accessibility trust without a prompt. Only `Enable Window Following` requests the system Accessibility prompt; denial or revocation never blocks launch, Usage display, or Quit.

Codex discovery uses only the exact reviewed bundle identifier `com.openai.codex` through the bundle-specific `NSRunningApplication` API. One candidate is selected directly. With multiple candidates, exactly one active candidate is selected; all other multiplicity is ambiguous. Workspace launch, termination, and activation notifications are filtered to the same exact bundle before entering the service.

## Window and Accessibility boundary

The target order is focused eligible standard window, main eligible standard window, then exactly one eligible visible non-minimized standard window. Zero-sized, minimized, sheet, dialog, popover, menu, tooltip, and other detectable non-standard/transient surfaces are rejected. Array order never chooses among multiple eligible windows.

Allowed AX attributes are limited to window list, focused/main window references, role, subrole, minimized, position, and size. Allowed notifications are moved, resized, miniaturized/deminiaturized, focused/main window changed, window created, target destroyed, plus exact Codex application lifecycle notifications. Titles, identifiers, accessibility labels, descriptions, values, selected text, document content, prompts, and responses are prohibited. A static boundary scan rejects textual AX attributes.

The selected AX element is retained only inside one process generation and is never serialized. Every resolve increments a generation. Coalesced callbacks carry that immutable generation; mismatched or post-stop callbacks are ignored. One callback box merges a movement burst into at most one main-actor delivery per 50 ms, prioritizing target invalidation and reselection over geometry. Stop deactivates the box, removes the run-loop source and registered notifications, and releases application/window/observer references.

## Coordinates and anchoring

Accessibility window geometry uses global coordinates whose origin is the upper-left of the primary display and whose Y axis increases downward. AppKit screen/window coordinates use a global Y-up convention. One converter applies:

```text
appKitX = axX
appKitY = primaryDisplayFrame.maxY - axY - axHeight
```

No pixel/backing-scale conversion is applied because both APIs report points. This convention preserves negative X for displays left of the primary display and negative AppKit Y for displays below it. Synthetic tests cover negative origins, mixed sizes, and a window crossing a display boundary. Screen arrangement changes cause geometry to be reread through the same converter.

The stable Halo reference is its upper-right point, matching the M3 compact/expanded resize behavior. Calibration projects that point onto the Codex window, stores the projected point as normalized window coordinates, and stores the fixed point offset from the projection to the Halo reference. Following recomputes the normalized point in the current window and adds the offset. The representation is independent of compact/expanded size and allows the Halo to remain beside, rather than inside, a window.

Final placement chooses the screen containing the anchor point. If no screen contains it, the nearest visible frame is used. The complete panel frame is clamped to that visible frame, respecting menu bar and Dock exclusions; an oversized frame is reduced to the available visible size. Screen indices are never persisted.

## Calibration and focus

Calibration is menu-controlled. The panel temporarily receives pointer events and its `HaloPanel` drag boundary moves the frame, but the panel retains `.nonactivatingPanel`, cannot become key or main, has no title bar, and is not resizable. Finish requires a current deterministic Codex target, computes and validates the anchor, then persists. Cancel restores the pre-calibration reference point. Compact click-through is restored after calibration; expanded keeps its existing scroll behavior. A drag alone never implies success.

## Persistence and fallback

Only following enabled and the version-1 anchor are stored in a dedicated namespaced preferences component. Decoding rejects unsupported versions, non-finite numbers, normalized points outside `0...1`, and offsets beyond 10,000 points. PID, AX identity, titles, paths, screen identity, account data, and Usage are not stored.

Absent permission, Codex, a deterministic window, valid calibration, or a working observer leaves the Halo visible at its last valid frame or M3 default. Temporary Codex loss does not erase calibration. Exact-bundle lifecycle events permit deterministic resumption without guessing. A five-second low-frequency trust check recognizes permission grant or revocation without prompting; it is a recovery path only, not the primary geometry tracker.

## Rejected alternatives and scope

Pet image recognition, OCR, screenshots, ScreenCaptureKit, broad window enumeration, title-based logic, private Codex IPC, and UI-text inspection are rejected. They require broader permissions, expose content, or claim semantics not proved by M4. Screen Recording is unnecessary because geometry and lifecycle come from Accessibility. Smooth animation, springs, glow, artwork, sound, and final themes remain M5 and are not introduced here.
