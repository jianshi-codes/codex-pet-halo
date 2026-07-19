# Pet Halo Project Plan

## Principles

- Pet Halo remains independent from Codex Desktop and Codex Pet.
- Experimental protocol data is converted into a stable internal model.
- Missing or unsupported data is displayed as unavailable, never estimated.
- Each milestone has an explicit gate and does not authorize the next one automatically.

## Milestones

### M0 — Protocol feasibility

Generate schemas from the installed Codex CLI, build a read-only protocol probe, capture redacted fixtures, and determine PASS-A/B/C. No production UI.

### M1 — Application skeleton

Only after M0 authorization: create the macOS/Xcode project, modules, CI, and application lifecycle skeleton.

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
