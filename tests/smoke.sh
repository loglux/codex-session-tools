#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP_DIR=$(mktemp -d)
DB_PATH="$TMP_DIR/test.sqlite"

cleanup() {
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT INT TERM

sqlite3 "$DB_PATH" <<'EOF'
create table threads (
  id text primary key,
  cwd text,
  rollout_path text,
  title text,
  created_at integer,
  updated_at integer
);
insert into threads values
  ('t1', '/old/project', '/old/home/.codex/sessions/a.log', 'one', 1, 10),
  ('t2', '/old/project', '/tmp/keep-/old/home/.codex/sessions/b.log', 'two', 2, 20),
  ('t3', '/other', '/old/home/.codex/sessions/c.log', 'three', 3, 30),
  ('t4', '/misc', '/misc', 'quote', 4, 40);
EOF

CODEX_STATE_DB="$DB_PATH" sh "$ROOT_DIR/scripts/migrate_codex_paths.sh" \
  --old-cwd /old/project \
  --new-cwd "/new/oleg's-project" \
  --show-only >/dev/null

CODEX_STATE_DB="$DB_PATH" sh "$ROOT_DIR/scripts/migrate_codex_paths.sh" \
  --all-threads \
  --old-rollout-prefix /old/home/.codex/sessions \
  --new-rollout-prefix /new/home/.codex/sessions \
  --no-backup >/dev/null

rollout_t1=$(sqlite3 "$DB_PATH" "select rollout_path from threads where id = 't1';")
rollout_t2=$(sqlite3 "$DB_PATH" "select rollout_path from threads where id = 't2';")
rollout_t3=$(sqlite3 "$DB_PATH" "select rollout_path from threads where id = 't3';")

[ "$rollout_t1" = "/new/home/.codex/sessions/a.log" ]
[ "$rollout_t2" = "/tmp/keep-/old/home/.codex/sessions/b.log" ]
[ "$rollout_t3" = "/new/home/.codex/sessions/c.log" ]

CODEX_STATE_DB="$DB_PATH" sh "$ROOT_DIR/scripts/rebind_codex_thread.sh" \
  --thread-id t4 \
  --new-cwd "/quoted/oleg's-repo" \
  --no-backup >/dev/null

t4_cwd=$(sqlite3 "$DB_PATH" "select cwd from threads where id = 't4';")
[ "$t4_cwd" = "/quoted/oleg's-repo" ]

CODEX_STATE_DB="$DB_PATH" sh "$ROOT_DIR/scripts/rebind_codex_threads_by_cwd.sh" \
  --old-cwd /old/project \
  --new-cwd /new/project \
  --no-backup >/dev/null

updated_count=$(sqlite3 "$DB_PATH" "select count(*) from threads where cwd = '/new/project';")
[ "$updated_count" = "2" ]

echo "smoke.sh: ok"
