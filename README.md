# Pet Halo for Codex

<p align="center">
  <img src="PetHalo/Assets.xcassets/AppIcon.appiconset/app-icon-256.png" width="128" height="128" alt="Pet Halo original three-ring app icon">
</p>

Pet Halo is a small macOS menu-bar companion that places a transparent Usage ring around Codex Pet. It shows weekly remaining Usage, an optional five-hour window, and Today compared with your historical daily peak. Compact and expanded fallback cards remain available when Pet is not the active target.

> Pet Halo is an independent, unofficial project. It is not affiliated with, endorsed by, or supported by OpenAI. Codex and Codex Pet are OpenAI products.

## Preview

<table>
  <tr>
    <td width="50%" align="center">
      <img src="docs/assets/screenshots/pet-halo-activity-above.png" width="100%" alt="Pet Halo with Codex activity above and Usage labels on the right">
    </td>
    <td width="50%" align="center">
      <img src="docs/assets/screenshots/pet-halo-activity-below.png" width="100%" alt="Pet Halo with Codex activity below and Usage labels on the left">
    </td>
  </tr>
  <tr>
    <td align="center">Activity above · labels on the right</td>
    <td align="center">Activity below · labels on the left</td>
  </tr>
</table>

Codex Pet is shown only to demonstrate integration. It is not Pet Halo project branding.

## Source Public Beta / Unsigned Developer Preview

The source code is ready for public use. The downloadable preview ZIP is unsigned and not notarized, so macOS may block its first launch. Only override Gatekeeper after independently verifying the GitHub source, release checksum, and repository provenance. A signed and notarized binary remains planned for a future Beta.

> **Unsigned preview warning:** `Pet-Halo-0.1.0-beta.1-unsigned-universal.zip` is not signed with a Developer ID certificate and is not notarized by Apple. Do not treat it as a signed or notarized release.

GitHub-hosted PRs, comments, reviews, Actions logs/artifacts, variables,
environments, tags, Releases, discussions, and Pages require the separate
[manual public-metadata checklist](docs/PUBLIC_EXPOSURE_AUDIT.md) immediately
before repository visibility changes.

## System requirements

- macOS 14.0 or later;
- Apple silicon or Intel Mac (`arm64` and `x86_64` are included in Release builds);
- Codex Desktop installed for Pet or window following;
- a supported Codex CLI installed and signed in for Usage data;
- Accessibility permission only if you enable following.

## Supported Codex versions

| Component | Supported version | Scope |
| --- | --- | --- |
| Codex CLI | `0.145.0-alpha.18` | Read-only Usage bridge and current generated protocol schemas |
| Codex Desktop | `26.715.31925 (5551)` | Previously validated Pet Accessibility geometry |
| Codex Desktop | `26.715.52143 (5591)` | Current M9 Route A and complete Pet-following gate validated |

Pet Halo checks the CLI version before launching its owned app-server. Unsupported or unparseable versions fail closed. A version is added only after initialize, account, rate-limit, Account Usage, notification, and JSON-RPC semantics have been reviewed—not merely because decoding succeeds. See [Compatibility](docs/COMPATIBILITY.md).

## Installation

When the unsigned Developer Preview artifact is published:

1. Download `Pet-Halo-0.1.0-beta.1-unsigned-universal.zip`, `SHA256SUMS`, `release-manifest.json`, and `RELEASE_NOTES.md` from `jianshi-codes/codex-pet-halo`.
2. Verify the archive:

   ```sh
   shasum -a 256 -c SHA256SUMS
   ```

3. Extract the ZIP and move **Pet Halo.app** to Applications.
4. Open Pet Halo. Because this preview is unsigned and not notarized, macOS may block its first launch.

Only override Gatekeeper after independently verifying the GitHub source, `SHA256SUMS`, and the `jianshi-codes/codex-pet-halo` repository provenance. Do not bypass Gatekeeper for an artifact presented as signed/notarized that fails verification.

## First run

1. Start Codex Desktop and make Pet visible.
2. Start Pet Halo from Applications. It appears in the menu bar and does not create a Dock app or normal window.
3. Confirm the menu says `Usage: Connected`. If it does not, use the troubleshooting table below.
4. Select **Enable Pet Following** only when you want Pet Halo to request Accessibility access.

Usage display does not require Accessibility. Following does.

## Why Accessibility permission is needed

Pet Halo uses macOS Accessibility only after an explicit enable action. It inspects the exact `com.openai.codex` application and only role/subrole, minimized/hidden state, position, size, and geometry/lifecycle notifications needed to identify and follow Pet or the standard Codex window.

It does not read titles, labels, document text, prompts, responses, conversation content, or selected text. It does not use Screen Recording, screenshots, or OCR. If permission is denied or revoked, Usage remains available and following fails closed.

## Enable Pet Following

1. Choose **Enable Pet Following** from the Pet Halo menu.
2. Grant Pet Halo access in **System Settings → Privacy & Security → Accessibility**.
3. Return to Pet Halo. A unique visible Pet is preferred automatically.

Target priority is Pet, then an explicitly calibrated Codex standard-window fallback, then free-floating placement. Ambiguous Pet geometry is never guessed.

## Adjust Ring Center

When Pet is selected, choose **Adjust Ring Center**. Drag the Ring or use the four-point nudge commands, then choose **Save Ring Center**. **Cancel** restores the prior value and **Reset Visual Center** returns to zero offset.

This setting moves the complete Ring surface by one bounded local offset. It does not change Pet discovery or persist Pet coordinates.

## Metrics

- **Weekly** — remaining percentage for the exact 10,080-minute Codex rate-limit window.
- **5h** — remaining percentage for an exact 300-minute window. It is omitted when Codex does not provide one.
- **Today / historical peak** — tokens in the current Codex UTC account day compared with the highest nonzero daily bucket supplied by Codex. Missing or ambiguous data is omitted, never estimated as zero.

Weekly and 5h use independent rate-limit freshness. Today uses independent Account Usage freshness, so a successful rate-only refresh cannot make stale Today data current.

## Tuck Away and fallbacks

When Pet is tucked away or unavailable, Pet Halo hides by default. **Use Codex Window Fallback** shows the calibrated Compact/Expanded card beside the standard Codex window. If no valid window anchor exists, placement remains free-floating. Wake returns to Pet when one unique supported target is available.

## Troubleshooting

| Menu state | What it means | Safe next step |
| --- | --- | --- |
| `Usage: Codex CLI not found` | No supported executable was found | Install or repair the Codex CLI, then relaunch Pet Halo |
| `Usage: Unsupported Codex CLI version` | The detected CLI has not passed semantic review | Check the compatibility table and file a sanitized compatibility report |
| `Usage: Sign in to Codex` | Authentication is unavailable | Sign in through Codex, then refresh Usage |
| `Usage: Rate limits temporarily unavailable` | The read-only rate snapshot failed | Wait and use **Refresh Usage**; no value is estimated |
| `Usage: Today temporarily unavailable` | Account Usage is unsupported or temporarily failed | Weekly may remain current; Today stays omitted/unavailable |
| `Following: Codex Not Running` | Codex Desktop is not available | Start Codex Desktop |
| `Following: Accessibility Required` | Permission is absent or was revoked | Re-enable Pet Halo in Accessibility settings |
| `Pet: Unavailable or Tucked Away` | No supported visible Pet target exists | Wake Pet, or use the Codex window fallback |
| `Pet: Target Ambiguous` | More than one eligible target remains | Tuck Away/Wake Pet; Pet Halo will not guess |

Public issue reports must not contain raw protocol payloads, tokens, account identity, conversation content, executable paths, raw Accessibility errors, or private screenshots. Follow [sanitized compatibility-report instructions](docs/COMPATIBILITY.md#sanitized-compatibility-reports).

## Privacy

Pet Halo launches one owned local `codex app-server --stdio` child and makes only read-only account/rate-limit/Usage requests. It stores no account identity or Usage data, makes no direct network request, and includes no telemetry, analytics, crash upload, updater, or cloud service. Local preferences contain only following enablement, a Codex-window anchor, and the bounded Ring visual-center offset.

See [Privacy](docs/PRIVACY.md) and [Security](SECURITY.md).

## Uninstall

1. Quit Pet Halo.
2. Move **Pet Halo.app** to Trash.
3. Optionally remove its local UI preferences:

   ```sh
   defaults delete io.github.jianshicodes.PetHalo
   ```

4. Optionally remove Pet Halo from **System Settings → Privacy & Security → Accessibility**.

No Usage database, account cache, updater, or background service is installed.

## Build from source

Xcode 26.4.1, Swift 6.3.1, and XcodeGen 2.46.0 are the current reviewed toolchain. `project.yml` is the editable Xcode project source of truth.

```sh
make bootstrap
make check
make release-unsigned-preview MARKETING_VERSION=0.1.0 BUILD_NUMBER=1 RELEASE_TAG=v0.1.0-beta.1
```

The unsigned preview target requires a clean source tree and produces `Pet-Halo-0.1.0-beta.1-unsigned-universal.zip`. Developer ID signing and Apple notarization remain separate credentialed steps described in [Release checklist](docs/RELEASE_CHECKLIST.md).

## Contributing and security

Read [Contributing](CONTRIBUTING.md), the [Code of Conduct](CODE_OF_CONDUCT.md), and the [Security Policy](SECURITY.md). Architecture decisions, compatibility evidence, and milestone reports remain under [`docs/`](docs/).

## License

MIT. See [LICENSE](LICENSE).
