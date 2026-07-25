# ADR 0011: Reserved Context Ring Slot

## Context

The Pet Ring's former Today metric came from Account Usage, whose refresh cadence
and upstream aggregation make it unsuitable as a live activity indicator. A first
implementation treated one eligible wide Accessibility surface as Live Activity.
Direct idle observation showed the same wide `AXDialog` and `AXSystemDialog`
surfaces persist while Codex is not working. Safe `AXHidden`, `AXElementBusy`, and
related Boolean state are unsupported on these surfaces.

## Decision

The Pet Ring no longer receives or renders Today token data. Its inner 84-point
radius remains a hidden context slot. Geometry may continue to select the shared
arc opening, but it must not be exposed as idle/working state.

Weekly and the optional exact 300-minute five-hour window are unchanged. Account
Usage remains available to fallback cards. If a future supported transport exposes
exact Context Remaining for the selected task, that metric may replace Live
Activity in the reserved inner slot under a separately reviewed change.

## Privacy and boundaries

Pet Halo does not read titles, labels, values, task content, or internal databases
and does not request Screen Recording. It also does not add visual detection,
process-activity heuristics, or an unsupported protocol path to approximate state.
Without an exact source, the inner slot fails closed by remaining hidden.
