#!/usr/bin/env bash
# ==============================================================================
#  Loads a database dump from an SQL file into MySQL/Postgres.
#  All configurations can be overridden by environment variables.
#
#  Usage:
#    ./load_data.sh [DSN] [SQL_FILE]
#
#  Environment Variables:
#    DSN:      Database connection string.
#              (Default: "mysql://root:mypwd@localhost:3306/BIRD")
#    SQL_FILE: Path to the .sql dump file.
#              (Default: "data/minidev/MINIDEV_mysql/BIRD_dev.sql")
# ==============================================================================
set -euo pipefail

# --- Configuration ---
DSN="${DSN:-mysql://root:mypwd@localhost:3306/BIRD}"
SQL_FILE="${SQL_FILE:-data/minidev/MINIDEV_mysql/BIRD_dev.sql}"

log() {
  echo "[INFO] $*"
}

error() {
  echo "[ERROR] $*" >&2
  exit 1
}

parse_dsn() {
  local dsn="$1"
  local regex="^([a-zA-Z\+]+)://(([^:@]+)(:([^@]*))?@)?([^:/]+)(:([0-9]+))?/(.*)$"

  if [[ ! $dsn =~ $regex ]]; then
    error "Invalid DSN format: ${dsn}"
  fi

  DB_TYPE=${BASH_REMATCH[1]}
  DB_USER=${BASH_REMATCH[3]}
  DB_PASSWORD=${BASH_REMATCH[5]}
  DB_HOST=${BASH_REMATCH[6]}
  DB_PORT=${BASH_REMATCH[8]}
  DB_NAME=${BASH_REMATCH[9]}
}

load_data() {
  local sql_file="$1"
  log "Loading data from '${sql_file}' into database '${DB_NAME}'..."

  case "$DB_TYPE" in
  mysql)
    local port=${DB_PORT:-3306}
    # Create DB if not exists
    mysql -h"$DB_HOST" -P"$port" -u"$DB_USER" -p"$DB_PASSWORD" \
          -e "CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    mysql -h"$DB_HOST" -P"$port" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" <"$sql_file"
    ;;

  postgresql | pgsql)
    local port=${DB_PORT:-5432}
    export PGPASSWORD="$DB_PASSWORD"
    # Create DB if not exists
    if ! psql -h "$DB_HOST" -p "$port" -U "$DB_USER" -lqt | cut -d \| -f 1 | grep -qw "$DB_NAME"; then
        log "Database '${DB_NAME}' does not exist. Creating it..."
        createdb -h "$DB_HOST" -p "$port" -U "$DB_USER" "$DB_NAME"
    fi
    psql -h "$DB_HOST" -p "$port" -U "$DB_USER" -d "$DB_NAME" -f "$sql_file" >/dev/null
    unset PGPASSWORD
    ;;

  *)
    error "Unsupported database type: '$DB_TYPE'"
    ;;
  esac
}

main() {
  if [ ! -f "$SQL_FILE" ]; then
    error "SQL file not found: '${SQL_FILE}'"
  fi

  log "Using the following configuration:"
  log "  DSN:      ${DSN}"
  log "  SQL File: ${SQL_FILE}"

  parse_dsn "$DSN"
  load_data "$SQL_FILE"

  log "Data import completed successfully."
}

main "$@"
