# ADR 0011: Conditional Live Activity Ring

## Context

The Pet Ring's former Today metric came from Account Usage, whose refresh cadence
and upstream aggregation make it unsuitable as a live activity indicator. The
existing Pet-following path already observes eligible wide Accessibility surfaces
using geometry and structure only.

## Decision

The Pet Ring no longer receives or renders Today token data. Its inner 84-point
radius is a context slot:

- while exactly one eligible activity surface produces an `above` or `below`
  geometry result, the slot shows an indeterminate Live Activity arc and capsule;
- `none`, `ambiguous`, Pet loss, fallback selection, and shutdown clear the state;
- the arc never represents percent complete, token volume, or task progress;
- Reduce Motion renders the same active state without movement.

Weekly and the optional exact 300-minute five-hour window are unchanged. Account
Usage remains available to fallback cards. If a future supported transport exposes
exact Context Remaining for the selected task, that metric may replace Live
Activity in the reserved inner slot under a separately reviewed change.

## Privacy and boundaries

The activity Boolean is derived only from the existing role, subrole, visibility,
size, and position contract. Pet Halo does not read titles, labels, values, task
content, or internal databases and does not request Screen Recording. Ambiguous
activity geometry fails closed.
