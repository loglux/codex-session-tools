#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/_codex_sqlite.sh"

DB_PATH="${CODEX_STATE_DB:-$HOME/.codex/state_5.sqlite}"
OLD_CWD=""
NEW_CWD=""
OLD_ROLLOUT_PREFIX=""
NEW_ROLLOUT_PREFIX=""
THREAD_ID=""
SHOW_ONLY=0
MAKE_BACKUP=1
ALL_THREADS=0

usage() {
  cat <<'EOF'
Usage:
  migrate_codex_paths.sh [selection] [rewrite] [options]

Selection:
  --thread-id ID              Update one specific thread
  --old-cwd PATH              Update all threads with this cwd
  --all-threads               Update all threads

Rewrite:
  --new-cwd PATH              New cwd value to write
  --old-rollout-prefix PATH   Old rollout_path prefix to replace
  --new-rollout-prefix PATH   New rollout_path prefix to write

Options:
  --db PATH                   Path to Codex SQLite DB. Default: $HOME/.codex/state_5.sqlite
  --show-only                 Preview matching rows and rewritten values without updating
  --no-backup                 Skip creating a .bak file before updating
  --help                      Show this help
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --db)
      DB_PATH="$2"
      shift 2
      ;;
    --thread-id)
      THREAD_ID="$2"
      shift 2
      ;;
    --old-cwd)
      OLD_CWD="$2"
      shift 2
      ;;
    --new-cwd)
      NEW_CWD="$2"
      shift 2
      ;;
    --old-rollout-prefix)
      OLD_ROLLOUT_PREFIX="$2"
      shift 2
      ;;
    --new-rollout-prefix)
      NEW_ROLLOUT_PREFIX="$2"
      shift 2
      ;;
    --all-threads)
      ALL_THREADS=1
      shift
      ;;
    --show-only)
      SHOW_ONLY=1
      shift
      ;;
    --no-backup)
      MAKE_BACKUP=0
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [ ! -f "$DB_PATH" ]; then
  echo "Codex DB not found: $DB_PATH" >&2
  exit 1
fi

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "sqlite3 is required" >&2
  exit 1
fi

selection_count=0
[ -n "$THREAD_ID" ] && selection_count=$((selection_count + 1))
[ -n "$OLD_CWD" ] && selection_count=$((selection_count + 1))
[ "$ALL_THREADS" -eq 1 ] && selection_count=$((selection_count + 1))

if [ "$selection_count" -ne 1 ]; then
  echo "Choose exactly one selector: --thread-id, --old-cwd, or --all-threads" >&2
  usage >&2
  exit 1
fi

if [ -z "$NEW_CWD" ] && [ -z "$OLD_ROLLOUT_PREFIX" ] && [ -z "$NEW_ROLLOUT_PREFIX" ]; then
  echo "Nothing to rewrite. Pass --new-cwd and/or rollout prefix options." >&2
  usage >&2
  exit 1
fi

if { [ -n "$OLD_ROLLOUT_PREFIX" ] && [ -z "$NEW_ROLLOUT_PREFIX" ]; } || \
   { [ -z "$OLD_ROLLOUT_PREFIX" ] && [ -n "$NEW_ROLLOUT_PREFIX" ]; }; then
  echo "Both --old-rollout-prefix and --new-rollout-prefix are required together" >&2
  usage >&2
  exit 1
fi

if [ -n "$THREAD_ID" ]; then
  THREAD_ID_SQL=$(sql_quote "$THREAD_ID")
  where_sql="id = $THREAD_ID_SQL"
elif [ -n "$OLD_CWD" ]; then
  OLD_CWD_SQL=$(sql_quote "$OLD_CWD")
  where_sql="cwd = $OLD_CWD_SQL"
else
  where_sql="1 = 1"
fi

if [ -n "$NEW_CWD" ]; then
  NEW_CWD_SQL=$(sql_quote "$NEW_CWD")
fi

if [ -n "$OLD_ROLLOUT_PREFIX" ]; then
  OLD_ROLLOUT_PREFIX_SQL=$(sql_quote "$OLD_ROLLOUT_PREFIX")
  NEW_ROLLOUT_PREFIX_SQL=$(sql_quote "$NEW_ROLLOUT_PREFIX")
  rollout_rewrite_sql="case when rollout_path = $OLD_ROLLOUT_PREFIX_SQL then $NEW_ROLLOUT_PREFIX_SQL when rollout_path like $OLD_ROLLOUT_PREFIX_SQL || '/%' then $NEW_ROLLOUT_PREFIX_SQL || substr(rollout_path, length($OLD_ROLLOUT_PREFIX_SQL) + 1) else rollout_path end"
fi

select_sql="select id, cwd, rollout_path, title from threads where $where_sql order by created_at desc;"
matches="$(sqlite3 "$DB_PATH" "$select_sql")"

if [ -z "$matches" ]; then
  echo "No matching threads found"
  exit 0
fi

echo "Matching thread records:"
printf '%s\n' "$matches"

preview_sql="select id, cwd as current_cwd, "
if [ -n "$NEW_CWD" ]; then
  preview_sql="$preview_sql $NEW_CWD_SQL as rewritten_cwd, "
else
  preview_sql="$preview_sql cwd as rewritten_cwd, "
fi

if [ -n "$OLD_ROLLOUT_PREFIX" ]; then
  preview_sql="$preview_sql rollout_path as current_rollout_path, $rollout_rewrite_sql as rewritten_rollout_path "
else
  preview_sql="$preview_sql rollout_path as current_rollout_path, rollout_path as rewritten_rollout_path "
fi

preview_sql="$preview_sql from threads where $where_sql order by created_at desc;"

echo "Rewritten preview:"
sqlite3 "$DB_PATH" "$preview_sql"

if [ "$SHOW_ONLY" -eq 1 ]; then
  exit 0
fi

if [ "$MAKE_BACKUP" -eq 1 ]; then
  backup_path="${DB_PATH}.bak-$(date +%Y%m%d-%H%M%S)"
  backup_sqlite_db "$DB_PATH" "$backup_path"
  echo "Backup created: $backup_path"
fi

set_sql="updated_at = strftime('%s','now')"
if [ -n "$NEW_CWD" ]; then
  set_sql="cwd = $NEW_CWD_SQL, $set_sql"
fi
if [ -n "$OLD_ROLLOUT_PREFIX" ]; then
  set_sql="rollout_path = $rollout_rewrite_sql, $set_sql"
fi

update_sql="pragma busy_timeout=5000; update threads set $set_sql where $where_sql; select changes();"

echo "Rows updated:"
sqlite3 "$DB_PATH" "$update_sql"

echo "Updated thread records:"
sqlite3 "$DB_PATH" "$select_sql"
