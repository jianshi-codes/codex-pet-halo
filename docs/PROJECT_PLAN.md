# Pet Halo Project Plan

## Principles

- Pet Halo remains independent from Codex Desktop and Codex Pet.
- Experimental protocol data is converted into a stable internal model.
- MVP metrics are capability-driven: optional segments appear only when their source is available.
- Missing or unsupported data is hidden or displayed as unavailable, never estimated.
- Each milestone has an explicit gate and does not authorize the next one automatically.

## Milestones

### M0 — Protocol feasibility

Generate schemas from the installed Codex CLI, build a read-only protocol probe, capture redacted fixtures, and assess core and optional capabilities. M0 passes when an owned stdio app-server can connect, return at least one usable account rate-limit window, return account usage, and degrade missing optional data safely. Five-hour and thread Context data are optional. No production UI.

### M1 — Application skeleton

After M0 PASS-CORE and separate implementation authorization: create the macOS/Xcode project, modules, CI, and application lifecycle skeleton. Do not require optional five-hour or Context sources to begin the skeleton.

### M2 — CodexBridge

Implement stable internal usage models, JSON-RPC transports, reconnection, version detection, and redacted logging.

### M3 — Halo window

Implement the non-activating transparent `NSPanel`, accessibility states, and compact/expanded layouts.

### M4 — Window following

Implement explicit calibration, multi-display handling, relative anchoring, and a free-floating fallback.

### M5 — Original visual design

Add original branding, motion preferences, themes, and low-usage states without official OpenAI or Codex Pet artwork.

### M6 — Hardening

Expand compatibility fixtures, transport/reconnect tests, UI/window tests, privacy audits, packaging, and release documentation.
