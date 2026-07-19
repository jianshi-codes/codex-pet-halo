# Codex app-server schema generation

- Codex CLI: `codex-cli 0.145.0-alpha.18`
- Generated at: 2026-07-19T16:15:20Z (JSON) / 2026-07-19T16:15:23Z (TypeScript)
- JSON files: 341
- TypeScript files: 685

Commands, run from the repository root:

```sh
codex app-server generate-json-schema --experimental \
  --out Tools/ProtocolProbe/Schemas/0.145.0-alpha.18/json

codex app-server generate-ts --experimental \
  --out Tools/ProtocolProbe/Schemas/0.145.0-alpha.18/typescript
```

The contents of `json/` and `typescript/` are unmodified CLI output. `GENERATION.md` is project metadata and is not generated protocol code.

Key generated types used by M0:

- `ClientRequest.ts` and `ServerNotification.ts` for method mapping;
- `v2/GetAccountRateLimitsResponse.ts`;
- `v2/RateLimitSnapshot.ts` and `v2/RateLimitWindow.ts`;
- `v2/AccountRateLimitsUpdatedNotification.ts`;
- `v2/GetAccountTokenUsageResponse.ts`;
- `v2/ThreadLoadedListResponse.ts`;
- `v2/ThreadStatusChangedNotification.ts`;
- `v2/ThreadTokenUsageUpdatedNotification.ts` and `v2/ThreadTokenUsage.ts`.
