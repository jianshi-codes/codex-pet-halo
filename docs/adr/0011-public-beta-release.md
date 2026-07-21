# ADR 0011 — Public Beta release boundary

## Status

Accepted. The source release path is ready; the signed binary gate remains blocked by external Developer ID credentials and subsequent clean-machine acceptance.

## Decision

The first distribution format is a minimal Universal ZIP. Release builds inject numeric marketing/build versions explicitly, use Release configuration and hardened runtime, and package only the application. The final archive is checksummed and accompanied by non-sensitive release notes and a manifest.

Developer ID signing, notarization, stapling, Gatekeeper verification, and clean-machine acceptance are required for `PASS — PUBLIC BETA READY`. Unsigned local packaging remains available for development. Credential material is external-only. App Sandbox is not enabled because it would change the separately reviewed Accessibility, CLI discovery, and owned child-process contracts.

GitHub publication is manual, prerelease-only, protected by an explicit input/environment, and unavailable from ordinary pushes or pull requests. M9 itself creates no tag or Release.

## Consequences

- A source-ready result may close as `PARTIAL — SOURCE RELEASE READY, SIGNED BINARY BLOCKED` only when Developer ID credentials are the sole external blocker.
- Notarization cannot be reported as passed without an actual Apple `Accepted` response.
- A DMG is deferred; it adds no required capability to the first Beta.
- The product UI, Usage metrics, target hierarchy, and privacy boundary remain frozen.
