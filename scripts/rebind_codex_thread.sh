#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
MIGRATE_SCRIPT="$SCRIPT_DIR/migrate_codex_paths.sh"

usage() {
  cat <<'EOF'
Usage:
  rebind_codex_thread.sh --thread-id ID --new-cwd PATH [options]

Compatibility wrapper around:
  migrate_codex_paths.sh --thread-id ID --new-cwd PATH [options]

Options:
  --db PATH          Path to Codex SQLite DB. Default: $HOME/.codex/state_5.sqlite
  --thread-id ID     Thread/session id from the `threads` table
  --new-cwd PATH     New repository path to bind the thread to
  --show-only        Print the matching thread and exit without updating
  --no-backup        Skip creating a .bak file before updating
  --help             Show this help
EOF
}

if [ ! -x "$MIGRATE_SCRIPT" ] && [ ! -f "$MIGRATE_SCRIPT" ]; then
  echo "Main migration script not found: $MIGRATE_SCRIPT" >&2
  exit 1
fi

case "${1:-}" in
  --help|-h)
    usage
    exit 0
    ;;
esac

exec sh "$MIGRATE_SCRIPT" "$@"
