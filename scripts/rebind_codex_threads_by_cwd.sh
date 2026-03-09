#!/bin/sh

set -eu

DB_PATH="${CODEX_STATE_DB:-$HOME/.codex/state_5.sqlite}"

usage() {
  cat <<'EOF'
Usage:
  rebind_codex_threads_by_cwd.sh --old-cwd PATH --new-cwd PATH [options]

Options:
  --db PATH          Path to Codex SQLite DB. Default: $HOME/.codex/state_5.sqlite
  --old-cwd PATH     Existing cwd to search for in the `threads` table
  --new-cwd PATH     New cwd to write into matching rows
  --show-only        Print matching threads and exit without updating
  --no-backup        Skip creating a .bak file before updating
  --help             Show this help
EOF
}

OLD_CWD=""
NEW_CWD=""
SHOW_ONLY=0
MAKE_BACKUP=1

while [ "$#" -gt 0 ]; do
  case "$1" in
    --db)
      DB_PATH="$2"
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

if [ -z "$OLD_CWD" ]; then
  echo "--old-cwd is required" >&2
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

select_sql="select id, cwd, rollout_path, title, created_at, updated_at from threads where cwd = '$OLD_CWD' order by created_at desc;"
matches="$(sqlite3 "$DB_PATH" "$select_sql")"

if [ -z "$matches" ]; then
  echo "No threads found for cwd: $OLD_CWD"
  exit 0
fi

echo "Matching thread records:"
printf '%s\n' "$matches"

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

sqlite3 "$DB_PATH" "pragma busy_timeout=5000; update threads set cwd = '$NEW_CWD', updated_at = strftime('%s','now') where cwd = '$OLD_CWD'; select changes();"

echo "Updated thread records:"
sqlite3 "$DB_PATH" "select id, cwd, rollout_path, title, created_at, updated_at from threads where cwd = '$NEW_CWD' order by created_at desc;"
