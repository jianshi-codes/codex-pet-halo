# ADR 0008: Automatic Center-Locked Pet Placement

- Status: Accepted for M6
- Decision: automatic Pet/Halo midpoint alignment with optional fine-tuned override

## Context

M5 proved a unique geometric Pet target but required a saved Pet-relative anchor before the Halo could follow it. First-use calibration is unnecessary because the panel can be centered directly on the Pet frame. Direct screenshots showed that inferring visible head/feet edges from the padded AX frame was unstable and produced large or wrong-side offsets.

## Decision

The placement mode is automatic when no valid Pet anchor exists and manual when one exists. Existing anchors migrate as manual overrides. Automatic placement stores no coordinates. Finish is the only manual persistence point; Cancel restores the previous state; Use Automatic Pet Placement clears only the Pet anchor.

The Accessibility boundary returns `PetEnvironmentSnapshot(petFrame, activityFrame, generation)`. It reads no content-bearing attributes. Activity selection is unique-or-none and never affects whether the Pet itself is valid.

The raw Route A Pet frame remains the discovery and manual-anchor reference. Automatic placement computes the panel frame directly around the Pet midpoint, without edge inference, distance offsets, available-space flips, or visible-frame clamps. The resulting `PetAttachmentLayout` retains orientation metadata for future artwork, but orientation cannot change the panel frame. M7 may move the visible Halo arc inside the transparent center-locked panel.

Pet movement and compact/expanded size changes recompute around the same midpoint. Fine-tuning keeps the existing manual-anchor contract, and generation checks reject stale callbacks.

## Consequences

First use attaches immediately, Wake recovers without user action, and M4/M3 remain intact. Existing calibration data is preserved. M7 receives an oriented layout boundary without coupling artwork to Accessibility or target selection.

The Route A AX composition and its transparent padding remain undocumented. Center locking avoids depending on any inferred visible edge. If Pet discovery fails, the service still falls back to M4/M3. No additional Accessibility attributes, Screen Recording, pixels, persistence, or logging are introduced.

## Rejected alternatives

- Persisting automatic coordinates: stale across Pet movement and display changes and unnecessary.
- Using `NSScreen.main`: wrong when Pet is on another or negative-coordinate display.
- Activity-relative panel placement: direct screenshots showed unstable side and distance results over the padded AX surface.
- Screen-half and available-space panel placement: changes the Pet/panel relationship even though the final Halo center is transparent.
- Replacing the M4 anchor: destroys the permanent fallback and violates milestone hierarchy.
- Adding final arc artwork or animation: owned by M7.
