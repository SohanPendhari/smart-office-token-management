#!/usr/bin/env bash
# Creates the database, schema and seed data. Usage: ./setup.sh [pg_user] [db_name]
set -e
PGUSER_NAME="${1:-postgres}"; DB="${2:-smart_office}"
cd "$(dirname "$0")"
psql -U "$PGUSER_NAME" -tc "SELECT 1 FROM pg_database WHERE datname='$DB'" | grep -q 1 || psql -U "$PGUSER_NAME" -c "CREATE DATABASE $DB"
psql -U "$PGUSER_NAME" -d "$DB" -v ON_ERROR_STOP=1 -f schema.sql
psql -U "$PGUSER_NAME" -d "$DB" -v ON_ERROR_STOP=1 -f seed.sql
echo "Database '$DB' is ready."
