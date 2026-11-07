# Weekly reset-time ring

The thin blue arc sits immediately inside the Weekly remaining-quota arc. It
uses the same start angle, direction, and 260-degree sweep in either orientation.
It is two points wide and fits between the existing Weekly and optional 5h quota
rings without occupying the reserved Context slot.

Time progress is `clamp((reportedReset - now) / 604800, 0, 1)`. Seven days is the
reference period; one second after a full reset this is 6 days, 23:59:59. This
reference does not assert that a provider always resets on that exact schedule.
No previous reset date is inferred. A missing reset timestamp hides the time
ring, unavailable weekly data hides it, and stale weekly data makes it faded and
dashed. At or after the reset it remains empty until the bridge reports a new
reset timestamp; it never invents another week. SwiftUI updates the arc every
hour without additional bridge calls or captures. Each tick changes the
reference by about 0.60% (1.55 degrees), with at most one hour of clock lag
between ticks. New bridge data can redraw it sooner. VoiceOver exposes its time
percentage and freshness separately from the quota percentage.

The existing quota arcs show **remaining**, not consumed, quota. For example,
39% weekly quota remaining against 50% time remaining means 61% has been consumed
in half the reference week: faster than uniform pacing. With 65% quota remaining
and 50% time remaining, consumption is slower than uniform pacing. Compare arc
fractions/end angles rather than pixel lengths because their radii differ.

## Preview generation

README images are native renders of `PetRingView` with synthetic quota values
and a reset 3.5 days away. They contain no captured Pet or account data and do
not represent the published Beta 10 build. The old Beta 8 screenshots remain as
historical assets.

From the repository root:

```sh
swiftc -module-cache-path /tmp/pet-halo-reset-module-cache -parse-as-library \
  Tools/ResetRingPreview/main.swift \
  PetHalo/Halo/PetRingView.swift PetHalo/Halo/PetRingGeometry.swift \
  PetHalo/Halo/PetRingPresentationModel.swift \
  PetHalo/Halo/PetRingPresentationPolicy.swift \
  PetHalo/Halo/PetRingAppearancePolicy.swift \
  PetHalo/Halo/WeeklyResetDateFormatter.swift \
  -o /tmp/pet-halo-reset-preview
/tmp/pet-halo-reset-preview
```

`PetRingPresentationMapperTests.testWeeklyResetProgressUsesSevenDaysAndClampsWithoutInventingReset`
covers missing reset, full week, one second after reset, half week, out-of-range
future timestamps, reset reached/past, and progress as the clock advances.
