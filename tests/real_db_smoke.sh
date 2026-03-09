#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
. "$ROOT_DIR/scripts/_codex_sqlite.sh"
SOURCE_DB="${CODEX_STATE_DB:-$HOME/.codex/state_5.sqlite}"
TMP_DIR=$(mktemp -d)
TEST_DB="$TMP_DIR/state_5.test.sqlite"

cleanup() {
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT INT TERM

if [ ! -f "$SOURCE_DB" ]; then
  echo "Codex DB not found: $SOURCE_DB" >&2
  exit 1
fi

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "sqlite3 is required" >&2
  exit 1
fi

sqlite3 "$SOURCE_DB" "vacuum into '$TEST_DB';"

thread_count=$(sqlite3 "$TEST_DB" "select count(*) from threads;")
if [ "$thread_count" = "0" ]; then
  echo "No threads found in copied DB" >&2
  exit 1
fi

sample_row=$(
  sqlite3 "$TEST_DB" "
    select id || char(31) || cwd || char(31) || rollout_path
    from threads
    order by updated_at desc
    limit 1;
  "
)

IFS="$(printf '\037')"
set -- $sample_row
IFS=" "
sample_id=$1
sample_cwd=$2
sample_rollout_path=$3

sample_id_sql=$(sql_quote "$sample_id")
sample_cwd_sql=$(sql_quote "$sample_cwd")

new_single_cwd="$sample_cwd.codex-test-single"
new_group_cwd="$sample_cwd.codex-test-group-$$"
new_group_cwd_sql=$(sql_quote "$new_group_cwd")

rollout_dir=$(dirname "$sample_rollout_path")
rollout_base=$(basename "$sample_rollout_path")
new_rollout_prefix="$TMP_DIR/relocated-sessions"
expected_rollout_path="$new_rollout_prefix/$rollout_base"

original_same_cwd_count=$(sqlite3 "$SOURCE_DB" "select count(*) from threads where cwd = $sample_cwd_sql;")

CODEX_STATE_DB="$TEST_DB" sh "$ROOT_DIR/scripts/codex_migrate.sh" \
  --old-cwd "$sample_cwd" \
  --new-cwd "$new_group_cwd" \
  --no-backup >/dev/null

copied_new_group_count=$(sqlite3 "$TEST_DB" "select count(*) from threads where cwd = $new_group_cwd_sql;")
[ "$copied_new_group_count" = "$original_same_cwd_count" ]

source_still_original=$(sqlite3 "$SOURCE_DB" "select count(*) from threads where cwd = $new_group_cwd_sql;")
[ "$source_still_original" = "0" ]

CODEX_STATE_DB="$TEST_DB" sh "$ROOT_DIR/scripts/codex_migrate.sh" \
  --thread-id "$sample_id" \
  --new-cwd "$new_single_cwd" \
  --no-backup >/dev/null

actual_single_cwd=$(sqlite3 "$TEST_DB" "select cwd from threads where id = $sample_id_sql;")
[ "$actual_single_cwd" = "$new_single_cwd" ]

CODEX_STATE_DB="$TEST_DB" sh "$ROOT_DIR/scripts/codex_migrate.sh" \
  --thread-id "$sample_id" \
  --old-rollout-prefix "$rollout_dir" \
  --new-rollout-prefix "$new_rollout_prefix" \
  --no-backup >/dev/null

actual_rollout_path=$(sqlite3 "$TEST_DB" "select rollout_path from threads where id = $sample_id_sql;")
[ "$actual_rollout_path" = "$expected_rollout_path" ]

echo "real_db_smoke.sh: ok"
echo "threads_copied=$thread_count"
echo "sample_id=$sample_id"
echo "sample_cwd=$sample_cwd"
echo "sample_rollout_prefix=$rollout_dir"
