# M5 Pet Target Discovery Report

## Decision

`ROUTE_A — PET_ACCESSIBILITY_WINDOW`

On the validation Codex Desktop build, the independently movable Pet is exposed by the exact `com.openai.codex` process as one logical near-square `AXWindow/AXDialog` frame. Two exactly overlapping AX surfaces may represent that logical frame. Pet Halo collapses only overlapping eligible frames; it never selects by array order, title, identifier, label, vertical relationship, or content.

The official [Codex Pets documentation](https://learn.chatgpt.com/docs/pets.md) describes the Pet, activity tray, status changes, Tuck Away/Wake, and position persistence. It does not document or guarantee the Accessibility window composition observed here. Route A is therefore a measured local compatibility contract, not a documented Codex API.

## Probe boundary

The local-only probe is `Tools/M5PetDiscovery`. It searches only the exact Codex bundle identifier and does not prompt unless `--request-accessibility` is explicitly supplied. Route A is evaluated before Route B.

The probe reads only:

- role and subrole;
- position and size;
- minimized and hidden state where present;
- enabled state and children only during the bounded Route B investigation.

It never reads title, value, description, help, identifier, selected text, visible character ranges, document content, prompts, responses, or conversation data. Sanitized output excludes PIDs, coordinates, titles, labels, identifiers, paths, raw trees, raw AX errors, account data, and Usage values.

Route B was bounded to depth 10, 1,500 visited nodes, 0.75 seconds, cycle detection, and explicit SIGINT cancellation. It was used only to reject a child-element route after Route A movement evidence was collected; it is not part of production.

## Sanitized observations

| Check | Observation |
| --- | --- |
| Visible Pet | Five non-standard AX windows were observed: three `AXDialog` and two `AXSystemDialog` surfaces across four distinct frames, with one two-surface overlap. |
| Independent movement | All five Route A surfaces moved while the standard Codex window stayed stationary. Two distinct movement trajectories separated the Pet core from its activity/control surfaces. |
| Core selection | Exactly one logical near-square `AXWindow/AXDialog` frame remained after filtering and overlap collapse. A wide activity dialog and `AXSystemDialog` controls were excluded. |
| Activity UI variation | The activity dialog could appear above or below the Pet and could add two controls. Vertical placement and control count are not selection inputs. |
| Selected-target sampling | A direct movement run recorded 175 unique samples, zero unavailable samples, and two transient ambiguous samples while the standard window stayed stationary. |
| Transient ambiguity | The two overlapping Pet layers can move non-atomically. Production coalesces callbacks for 80 ms, rechecks after 160 ms, and falls back rather than guessing if ambiguity persists. |
| Pet hidden | Route A candidate count fell to zero. Route B retained only standard-window structural controls and did not move with the Pet. |
| Pet recreation | A lifecycle run observed the full surface set, a single residual dialog, no Pet surfaces, and the full surface set again. The target was rediscovered without content inspection. |
| Route B movement | The bounded standard-window descendant sample exposed only a small geometry/structure set; no candidate followed independent Pet movement. |
| Production following | After Pet calibration, the Halo followed independent Pet movement. Tuck Away activated the calibrated window fallback; Wake restored Pet following without recalibration. |
| Calibration stability | A recovery tick originally reset an unfinished Pet calibration because its active source still appeared as the window fallback. Recovery/display placement is now paused during calibration, and a delayed calibration remained stable beyond that tick. |

User-provided screenshots helped identify that the wide activity dialog changes sides and may expose buttons. They are not committed, captured by the application, or used by product logic.

## Deterministic selection rule

1. Obtain windows only from the selected exact Codex process.
2. Require `AXWindow/AXDialog`, visible, non-minimized, finite positive geometry.
3. Require a near-square aspect ratio from 0.8 through 1.5.
4. Quantize geometry to half-point keys and collapse exactly overlapping logical surfaces.
5. Select only when exactly one logical frame group exists.
6. Return unavailable for zero groups and ambiguous for multiple groups.

The selected frame is the deterministic average of members in the sole overlap group. Candidate identities remain internal to one accessor call and are never persisted or exposed.

## Route conclusion

Route A satisfies the discovery proof: the candidate exists with Pet, follows independent Pet movement while the standard window remains stationary, excludes activity/control surfaces, is selected without titles or ordering, disappears with Pet, and can be rediscovered after Wake. Route B does not supply a Pet-relative descendant. Screen Recording, screenshots, ScreenCaptureKit, OCR, and visual detection are neither required nor authorized.

The known compatibility risk is the undocumented AX composition. Any future Codex version that changes role/subrole, geometry layering, or notification behavior must fail closed to the M4 Codex-window anchor and then the M3 free-floating position.
