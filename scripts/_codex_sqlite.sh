#!/bin/sh

sql_quote() {
  escaped=$(printf '%s' "$1" | sed "s/'/''/g")
  printf "'%s'" "$escaped"
}

backup_sqlite_db() {
  db_path=$1
  backup_path=$2
  sqlite3 "$db_path" "vacuum into $(sql_quote "$backup_path");"
}
