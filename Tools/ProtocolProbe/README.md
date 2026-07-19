# Protocol Probe

This directory contains the M0-only read-only Codex app-server probe and CLI-generated schemas. It is not a production runtime dependency.

## Safety boundary

The probe sends only:

- `initialize`, followed by `initialized`;
- `account/read` with `refreshToken: false`;
- `account/rateLimits/read`;
- `account/usage/read`;
- `thread/loaded/list`.

It never sends `thread/start`, `turn/start`, task prompts, or mutation requests. Raw payloads are kept only in memory. Files are written after recursive redaction; unknown strings, identifiers, content, local paths, and token-count metrics are redacted by default.

## Usage

Independent stdio fallback:

```sh
python3 Tools/ProtocolProbe/probe.py \
  --transport stdio \
  --timeout 15 \
  --observe-seconds 5 \
  --output-dir /tmp/pet-halo-probe
```

Current CLI control-socket discovery, with no hardcoded path:

```sh
python3 Tools/ProtocolProbe/probe.py \
  --transport proxy \
  --timeout 8 \
  --observe-seconds 10 \
  --output-dir /tmp/pet-halo-proxy-probe
```

`--transport proxy` launches `codex app-server proxy`; the installed CLI performs default control-socket discovery. `--socket` exists only for an explicit operator-provided path and is never inferred by the probe.
