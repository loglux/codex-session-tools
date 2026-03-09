# Codex Session Tools

Small maintenance helpers for repairing Codex session metadata after:

- repository renames
- directory moves
- migrations to another machine
- restoring `~/.codex` into a different filesystem layout

These scripts are meant for local maintenance of Codex history. They do not
talk to a server. They only rewrite local metadata in the Codex SQLite state
database.

## Repository Layout

```text
codex-session-tools/
├── README.md
└── scripts/
    ├── _codex_sqlite.sh
    ├── migrate_codex_paths.sh
    ├── rebind_codex_thread.sh
    └── rebind_codex_threads_by_cwd.sh
```

Run every example from the root of this repository:

```sh
cd /volume1/projects/codex-session-tools
```

## What These Scripts Touch

By default the scripts operate on:

```text
$HOME/.codex/state_5.sqlite
```

They update rows in the `threads` table, mainly these fields:

- `cwd`
- `rollout_path`
- `updated_at`

They do not modify the session log contents themselves.

## Core Concepts

There are two different kinds of paths involved.

### `cwd`

This is the project directory that the thread was originally associated with.

Example:

- old `cwd`: `/volume1/projects/ring-rtsp-stream`
- new `cwd`: `/volume1/projects/ring-rtsp-bridge`

You rewrite `cwd` when:

- a repository was renamed
- a project directory was moved
- the same project now lives in another path on the new machine

### `rollout_path`

This is the absolute path to the Codex session log file itself.

Example:

- old `rollout_path` prefix: `/home/olduser/.codex/sessions`
- new `rollout_path` prefix: `/home/simulacra/.codex/sessions`

You rewrite `rollout_path` when:

- you copied `~/.codex` from another machine
- the username or home directory changed
- the Codex session logs now live under a different absolute path

## Which Script To Use

`scripts/migrate_codex_paths.sh` is the main entrypoint.

The other two scripts are compatibility wrappers for convenience:

- `scripts/rebind_codex_thread.sh`
- `scripts/rebind_codex_threads_by_cwd.sh`

### `scripts/rebind_codex_thread.sh`

Compatibility wrapper for:

```sh
sh scripts/migrate_codex_paths.sh --thread-id ... --new-cwd ...
```

Use this when you know the exact `thread_id` and only want to fix one thread.

Example:

```sh
sh scripts/rebind_codex_thread.sh \
  --thread-id 019cd22e-20a4-7bd2-bf59-c02e84debc35 \
  --new-cwd /volume1/projects/ring-rtsp-bridge
```

### `scripts/rebind_codex_threads_by_cwd.sh`

Compatibility wrapper for:

```sh
sh scripts/migrate_codex_paths.sh --old-cwd ... --new-cwd ...
```

Use this when one project was renamed or moved and you want to update every
thread that still points at the old project path.

Example:

```sh
sh scripts/rebind_codex_threads_by_cwd.sh \
  --old-cwd /volume1/projects/ring-rtsp-stream \
  --new-cwd /volume1/projects/ring-rtsp-bridge
```

### `scripts/migrate_codex_paths.sh`

Use this for general migrations. It is the main script and the most flexible
entrypoint.

It supports three selection modes:

- `--thread-id ID`
- `--old-cwd PATH`
- `--all-threads`

It can rewrite:

- only `cwd`
- only the `rollout_path` prefix
- both in one run

## Safety Model

Every write operation creates a timestamped backup of the SQLite database by
default.

Example backup name:

```text
~/.codex/state_5.sqlite.bak-20260309-121530
```

Recommended habit:

1. Run with `--show-only`.
2. Read the preview carefully.
3. Run the real command without `--show-only`.

Use `--no-backup` only if you have a strong reason.

## Test On A Copy Of Your Real Database

If you want extra confidence before running a real migration, you can test the
scripts against a temporary copy of your actual Codex state database.

This repository includes:

- `tests/smoke.sh` for a synthetic temporary SQLite database
- `tests/real_db_smoke.sh` for a copied snapshot of your real `state_5.sqlite`

The real-db smoke test:

- copies `$HOME/.codex/state_5.sqlite` into a temporary file
- runs all three migration helpers against the copy
- verifies that the original database was not modified

Run it from the repository root:

```sh
sh tests/real_db_smoke.sh
```

To point it at another database file:

```sh
CODEX_STATE_DB=/path/to/state_5.sqlite sh tests/real_db_smoke.sh
```

## Common Scenarios

### 1. Only The Project Path Changed

You renamed or moved the repository, but the Codex home stayed the same.

Example:

- old project path: `/volume1/projects/ring-rtsp-stream`
- new project path: `/volume1/projects/ring-rtsp-bridge`
- Codex logs still live in `/home/simulacra/.codex/sessions`

Preview:

```sh
sh scripts/migrate_codex_paths.sh \
  --old-cwd /volume1/projects/ring-rtsp-stream \
  --new-cwd /volume1/projects/ring-rtsp-bridge \
  --show-only
```

Apply:

```sh
sh scripts/migrate_codex_paths.sh \
  --old-cwd /volume1/projects/ring-rtsp-stream \
  --new-cwd /volume1/projects/ring-rtsp-bridge
```

### 2. Only The Codex Home Changed

The project path stayed the same, but you copied `~/.codex` from another
machine or another user account.

Example:

- old rollout prefix: `/home/olduser/.codex/sessions`
- new rollout prefix: `/home/simulacra/.codex/sessions`

Preview:

```sh
sh scripts/migrate_codex_paths.sh \
  --all-threads \
  --old-rollout-prefix /home/olduser/.codex/sessions \
  --new-rollout-prefix /home/simulacra/.codex/sessions \
  --show-only
```

Apply:

```sh
sh scripts/migrate_codex_paths.sh \
  --all-threads \
  --old-rollout-prefix /home/olduser/.codex/sessions \
  --new-rollout-prefix /home/simulacra/.codex/sessions
```

### 3. Both The Project Path And Codex Home Changed

This is the typical cross-machine migration.

Example:

- old project path: `/old/projects/ring-rtsp-stream`
- new project path: `/volume1/projects/ring-rtsp-bridge`
- old rollout prefix: `/home/olduser/.codex/sessions`
- new rollout prefix: `/home/simulacra/.codex/sessions`

Preview:

```sh
sh scripts/migrate_codex_paths.sh \
  --old-cwd /old/projects/ring-rtsp-stream \
  --new-cwd /volume1/projects/ring-rtsp-bridge \
  --old-rollout-prefix /home/olduser/.codex/sessions \
  --new-rollout-prefix /home/simulacra/.codex/sessions \
  --show-only
```

Apply:

```sh
sh scripts/migrate_codex_paths.sh \
  --old-cwd /old/projects/ring-rtsp-stream \
  --new-cwd /volume1/projects/ring-rtsp-bridge \
  --old-rollout-prefix /home/olduser/.codex/sessions \
  --new-rollout-prefix /home/simulacra/.codex/sessions
```

### 4. Only One Thread Needs Repair

If one session is misbound but the rest are fine:

Preview:

```sh
sh scripts/rebind_codex_thread.sh \
  --thread-id 019cd22e-20a4-7bd2-bf59-c02e84debc35 \
  --show-only
```

Apply:

```sh
sh scripts/rebind_codex_thread.sh \
  --thread-id 019cd22e-20a4-7bd2-bf59-c02e84debc35 \
  --new-cwd /volume1/projects/ring-rtsp-bridge
```

## Typical Cross-Machine Workflow

If you want to move Codex history from one machine to another, the process is
usually:

1. Copy these files and directories from the old machine:
   - `~/.codex/state_5.sqlite`
   - `~/.codex/history.jsonl`
   - `~/.codex/sessions/`
2. Place them under `~/.codex/` on the new machine.
3. Run a preview migration with `--show-only`.
4. Confirm that the previewed `cwd` and `rollout_path` values are correct.
5. Run the real migration command.

## What `--show-only` Does

`--show-only` does not write anything. It prints:

- which rows matched
- the current values
- the rewritten values that would be stored

That preview is the safest way to catch:

- a typo in the old project path
- a typo in the new project path
- the wrong old home directory
- a wider match set than you intended

## Limits And Non-Goals

These tools are intentionally narrow.

They do not:

- recreate missing session logs
- merge two different `thread_id` values into one thread
- rewrite `history.jsonl`
- guarantee that the Codex UI will merge separate conversations
- handle future schema changes automatically

They only repair stored path metadata so Codex has a better chance of finding
the existing local history correctly.

## Practical Advice

- Always start with `--show-only`.
- Keep the backup until you verify the result in the client.
- For one renamed repository, prefer `rebind_codex_threads_by_cwd.sh`.
- For machine migrations, prefer `migrate_codex_paths.sh`.
- If you are unsure whether the problem is project path or Codex home path,
  inspect both before writing anything.
