# Visual Pet resource probe

A macOS-only, read-only profiler for a supplied process. It reads public
`proc_pid_rusage(RUSAGE_INFO_V6)` counters, never captures the screen, and
prints aggregate numeric resource samples. It is not bundled with Pet Halo.

```sh
xcrun clang Tools/VisualPetResources/main.c -o /tmp/pet-resource-probe
/tmp/pet-resource-probe <pid> 15
```

Fifteen samples at two-second intervals cover approximately 30 seconds.
CPU time counters are Mach absolute ticks and must be converted with the
host's Mach timebase. CPU percentage uses one core as 100%. Physical
footprint and resident size are different memory metrics; both are reported
in MiB. Energy uses the delta of `ri_energy_nj` divided by actual elapsed
time to report the operating system's estimated process-attributed watts,
not measured whole-machine power or total capture-system cost. Shared
WindowServer/capture service work is not fully represented. A zero energy
counter means unavailable/unreported, not proof of zero consumption.

Record the visual-following mode and confirmed target state separately.
Use the same application build configuration, machine, sample duration, and
Pet operations for comparisons; avoid simultaneous builds or image probes.
Manual drag speed and incidental UI activity are uncontrolled, so these
short runs are indicative rather than a controlled energy benchmark.
