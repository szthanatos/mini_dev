#!/usr/bin/env bash
# ==============================================================================
#  environment:
#  - $DSN: protocol://user:pass@host:port/dbname
#  - $SQL_FILE: /path/to/your/dump.sql
#
#  usage:
#  ./import_database.sh
#  ./import_database.sh "$DSN" "$SQL_FILE"
#
#  eg:
#  ./import_database.sh "mysql://myuser:pass@host.com:3306/testdb" "../data/minidev/MINIDEV_mysql/BIRD_dev.sql"
#  ./import_database.sh "postgresql://pguser:pgpass@localhost:5432/proddb" "../data/minidev/MINIDEV_postgresql/BIRD_dev.sql"
# ==============================================================================
set -e

parse_dsn() {
    local DSN="$1"
    local REGEX="^([a-zA-Z\+]+)://(([^:@]+)(:([^@]*))?@)?([^:/]+)(:([0-9]+))?/(.*)$"

    if [[ $DSN =~ $REGEX ]]; then
        DB_TYPE=${BASH_REMATCH[1]}
        DB_USER=${BASH_REMATCH[3]}
        DB_PASSWORD=${BASH_REMATCH[5]}
        DB_HOST=${BASH_REMATCH[6]}
        DB_PORT=${BASH_REMATCH[8]}
        DB_NAME=${BASH_REMATCH[9]}
    else
        echo "Invalid DSN URI: $DSN" >&2
        exit 1
    fi
}

load_data() {
    local SQL_FILE="$1"
    echo "loading '$SQL_FILE' into '$DB_NAME'..."

    case "$DB_TYPE" in
    mysql)
        local port=${DB_PORT:-3306}
        mysql -h"$DB_HOST" -P"$port" -u"$DB_USER" -p"$DB_PASSWORD" -e "CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
        mysql -h"$DB_HOST" -P"$port" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" <"$SQL_FILE"
        ;;
    postgresql | pgsql)
        local port=${DB_PORT:-5432}
        export PGPASSWORD="$DB_PASSWORD"
        if ! psql -h "$DB_HOST" -p "$port" -U "$DB_USER" -d "$DB_NAME" -c '\q' &>/dev/null; then
            createdb -h "$DB_HOST" -p "$port" -U "$DB_USER" "$DB_NAME"
        fi
        psql -h "$DB_HOST" -p "$port" -U "$DB_USER" -d "$DB_NAME" -f "$SQL_FILE"
        unset PGPASSWORD
        ;;
    *)
        echo "Invalid DB type '$DB_TYPE'" >&2
        exit 1
        ;;
    esac
}

main() {
    local dsn_to_use=${1:-$DSN}
    local sql_file_to_use=${2:-$SQL_FILE}

    if [ -z "$dsn_to_use" ]; then
        echo "DSN must be setup." >&2
        echo "usage: $0 <DSN_URI> <SQL_FILE_PATH>" >&2
        exit 1
    fi

    if [ ! -f "$sql_file_to_use" ]; then
        echo "No such file: $sql_file_to_use" >&2
        exit 1
    fi

    parse_dsn "$dsn_to_use"
    load_data "$sql_file_to_use"

    echo "Data import success."
}

main "$@"
