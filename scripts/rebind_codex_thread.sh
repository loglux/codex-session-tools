#!/bin/sh

set -eu

DB_PATH="${CODEX_STATE_DB:-$HOME/.codex/state_5.sqlite}"

usage() {
  cat <<'EOF'
Usage:
  rebind_codex_thread.sh --thread-id ID --new-cwd PATH [options]

Options:
  --db PATH          Path to Codex SQLite DB. Default: $HOME/.codex/state_5.sqlite
  --thread-id ID     Thread/session id from the `threads` table
  --new-cwd PATH     New repository path to bind the thread to
  --show-only        Print the matching thread and exit without updating
  --no-backup        Skip creating a .bak file before updating
  --help             Show this help
EOF
}

THREAD_ID=""
NEW_CWD=""
SHOW_ONLY=0
MAKE_BACKUP=1

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
    --new-cwd)
      NEW_CWD="$2"
      shift 2
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

if [ -z "$THREAD_ID" ]; then
  echo "--thread-id is required" >&2
  usage >&2
  exit 1
fi

if [ ! -f "$DB_PATH" ]; then
  echo "Codex DB not found: $DB_PATH" >&2
  exit 1
fi

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "sqlite3 is required" >&2
  exit 1
fi

select_sql="select id, cwd, rollout_path, title, created_at, updated_at from threads where id = '$THREAD_ID';"
thread_row="$(sqlite3 "$DB_PATH" "$select_sql")"

if [ -z "$thread_row" ]; then
  echo "Thread not found: $THREAD_ID" >&2
  exit 1
fi

echo "Current thread record:"
printf '%s\n' "$thread_row"

if [ "$SHOW_ONLY" -eq 1 ]; then
  exit 0
fi

if [ -z "$NEW_CWD" ]; then
  echo "--new-cwd is required unless --show-only is used" >&2
  usage >&2
  exit 1
fi

if [ "$MAKE_BACKUP" -eq 1 ]; then
  backup_path="${DB_PATH}.bak-$(date +%Y%m%d-%H%M%S)"
  cp "$DB_PATH" "$backup_path"
  echo "Backup created: $backup_path"
fi

sqlite3 "$DB_PATH" "pragma busy_timeout=5000; update threads set cwd = '$NEW_CWD', updated_at = strftime('%s','now') where id = '$THREAD_ID';"

echo "Updated thread record:"
sqlite3 "$DB_PATH" "$select_sql"
