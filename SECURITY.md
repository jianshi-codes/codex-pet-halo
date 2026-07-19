# Security Policy

## Reporting

Please report suspected security or privacy issues privately through GitHub Security Advisories once the repository is public. Do not include live credentials or unredacted user data in an issue.

## M0 security boundary

- Pet Halo uses documented app-server transports exposed by the installed Codex CLI.
- It does not inspect Codex internal databases, patch Codex Desktop, or modify Codex Pet.
- The M0 probe sends only initialization and explicitly listed read-only requests.
- Probe output is deny-by-default: raw payloads are written only after recursive redaction, and unknown identity/path fields are redacted conservatively.
- Access tokens, authentication headers, email addresses, account identifiers, thread content, and absolute local paths must never be committed.

The Codex app-server protocol is experimental. Treat schema and transport changes as compatibility and security events.
