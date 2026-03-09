# Codex Session Tools

One practical script for repairing Codex path metadata in the local SQLite
state database.

## Files

```text
codex-session-tools/
├── README.md
├── scripts/
│   └── codex_migrate.sh
└── tests/
    ├── real_db_smoke.sh
    └── smoke.sh
```

Run all examples from the repo root:

```sh
cd /volume1/projects/codex-session-tools
```

## What It Changes

Default database:

```text
$HOME/.codex/state_5.sqlite
```

The script updates rows in `threads`, mainly:

- `cwd`
- `rollout_path`
- `updated_at`

It does not rewrite session log contents.

## Main Command

```sh
sh scripts/codex_migrate.sh --help
```

Rules:

- choose exactly one selector: `--thread-id`, `--old-cwd`, or `--all-threads`
- choose at least one rewrite: `--new-cwd` and/or rollout prefix rewrite
- use `--show-only` first

## Common Tasks

Rename or move one project:

```sh
sh scripts/codex_migrate.sh \
  --old-cwd /volume1/projects/old-name \
  --new-cwd /volume1/projects/new-name \
  --show-only
```

Apply it:

```sh
sh scripts/codex_migrate.sh \
  --old-cwd /volume1/projects/old-name \
  --new-cwd /volume1/projects/new-name
```

Fix one thread by id:

```sh
sh scripts/codex_migrate.sh \
  --thread-id 019cd22e-20a4-7bd2-bf59-c02e84debc35 \
  --new-cwd /volume1/projects/ring-rtsp-bridge
```

Rewrite rollout paths after moving `~/.codex`:

```sh
sh scripts/codex_migrate.sh \
  --all-threads \
  --old-rollout-prefix /home/olduser/.codex/sessions \
  --new-rollout-prefix /home/simulacra/.codex/sessions
```

Change both project path and rollout path:

```sh
sh scripts/codex_migrate.sh \
  --old-cwd /old/projects/ring-rtsp-stream \
  --new-cwd /volume1/projects/ring-rtsp-bridge \
  --old-rollout-prefix /home/olduser/.codex/sessions \
  --new-rollout-prefix /home/simulacra/.codex/sessions
```

## Safety

By default the script creates a timestamped SQLite backup before writing.

Recommended flow:

1. Run with `--show-only`.
2. Check the preview.
3. Run the real command.

Use `--no-backup` only if you intentionally want to skip that backup.

## Tests

Synthetic smoke test:

```sh
sh tests/smoke.sh
```

Smoke test on a temporary copy of your real database:

```sh
sh tests/real_db_smoke.sh
```

Or with another database path:

```sh
CODEX_STATE_DB=/path/to/state_5.sqlite sh tests/real_db_smoke.sh
```
