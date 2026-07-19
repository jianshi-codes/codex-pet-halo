# M3 Halo Window

- Status: **PASS**
- Date: 2026-07-20
- Scope: one non-activating Halo panel, compact/expanded Usage presentation, menu controls, accessibility, lifecycle integration, deterministic tests, local smoke, documentation, and CI gates
- Stop condition: M3 Draft PR; do not implement M4 following/calibration or M5 visual design

## Implemented architecture

`ApplicationCoordinator` owns one `HaloPanelController` and is the sole consumer of the bridge state stream. It publishes the latest `CodexUsageState`, converts it through a deterministic `HaloPresentationMapper`, and sends only UI-facing values to the panel. The mapper uses rate-limit freshness for weekly/five-hour values and Account Usage freshness for Account Usage; aggregate timestamps never promote a stale component.

`HaloPanel` is borderless and non-activating, cannot become key or main, has a transparent non-opaque background, floats above normal windows, joins Spaces, supports full-screen auxiliary presentation, and is omitted from normal cycling. One SwiftUI hosting view switches between 176×176 compact and 360×520 expanded layouts. Both modes set `ignoresMouseEvents` and are controlled from the menu bar, so the Halo does not intercept clicks or keyboard focus. Show, hide, and mode changes are idempotent. Shutdown stops and releases the panel's hosted content before awaiting the owned app-server.

The initial panel frame is contained within one available screen's visible frame and placed at its upper-right with a fixed 24-point inset. There is no Codex/Pet lookup, relative anchor, saved frame, screen tracking, or movement after launch.

## Presentation semantics

The compact view uses the domain's remaining percentage directly for a neutral circular weekly gauge and deterministic whole-percent rounding. It shows retained stale values only with a visible `Stale` label, distinguishes connected-but-weekly-unavailable from an unavailable bridge, and omits five-hour entirely unless an exact 300-minute capability exists.

Expanded mode shows weekly and optional five-hour reset information, per-component status, only present Account Usage summary fields, and at most seven recent daily rows in descending date order. Nil values are omitted rather than converted to zero. Context, account identity, raw failures, DTOs, and protocol payloads are absent from the presentation model and UI.

Accessibility strings include metric identity, percentage, current/stale/unavailable state, and an absolute localized reset value. The compact surface is one coherent accessibility element; expanded sections have explicit labels. Decorative gauge shapes are hidden. Status is textual rather than color-only. System text/colors support light and dark appearances, Reduce Transparency substitutes an opaque system background, and Differentiate Without Color adds an outline.

## Verification

| Evidence | Result |
| --- | --- |
| `make m3-tests` | PASS — 20 focused presentation, accessibility, real-panel, and coordinator tests |
| `make test` | PASS — 51 Core tests plus 23 application tests; 1 local-only smoke skipped, 0 failures |
| `make m0-tests` | PASS — 14 retained tests |
| `make check` | PASS — project drift, source/privacy boundaries, Debug, universal Release, bundles, Swift tests, and retained M0 tests |
| `make m2-smoke` | PASS — local read-only bridge capabilities and clean owned-child shutdown; sanitized output only |
| `make m3-smoke` | PASS — focused M3 tests plus authenticated accessory/panel/child lifecycle checks; sanitized output only |
| Runtime inspection | PASS — one compact Halo, accessory policy, no activation, no regular window beyond Halo, no Dock icon, clean panel/child shutdown |
| Manual UI observation | PASS — authenticated compact weekly content, absent unavailable five-hour, and click-through with the application remaining inactive; expanded/menu/appearance variants are deterministic code and test evidence, not external smoke claims |

CI runs `make check` without Codex, authentication, Accessibility permission, Screen Recording, secrets, or the real smoke path.

## Boundary and gate

Production source checks reject other-process Accessibility inspection, screen capture, CGWindow enumeration, `NSWorkspace` scanning, thread/turn methods, internal databases, and Usage persistence. Bundle checks reject fixtures, fake servers, schemas, smoke/report material, and debug harnesses. No M4 calibration/following or M5 artwork/motion/theme code exists.

All M3 exit criteria pass. The next recommended milestone is separately authorized **M4 — Window following**. This result does not authorize or begin M4.
