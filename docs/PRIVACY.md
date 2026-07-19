# Privacy

Pet Halo is designed to expose only the minimum local usage state needed for its display.

## Data boundaries

M0 may inspect read-only account availability, rate-limit windows, loaded-thread metadata, connection state, and token-usage counters through the Codex app-server protocol. It must not execute tasks, mutate threads, inspect conversation content, read Codex internal SQLite databases, or modify Codex Desktop or Codex Pet.

## Never stored

- ChatGPT or Codex access tokens;
- authorization headers or cookies;
- email addresses or full account profiles;
- stable account identifiers;
- thread content, prompts, or responses;
- local home directories, project absolute paths, or other user-identifying data.

Committed fixtures are recursively redacted. A fixture is evidence of payload structure, not a replay of a user's account or thread.
