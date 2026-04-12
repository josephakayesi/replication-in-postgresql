#!/bin/bash
set -e

PRIMARY_HOST="${PRIMARY_HOST:-primary}"

echo "Waiting for primary to be ready..."
until pg_isready -h "$PRIMARY_HOST" -p 5432 -U postgres; do
  sleep 2
done

# Skip pg_basebackup if data directory is already initialized (e.g. container restart)
if [ -f "$PGDATA/PG_VERSION" ]; then
  echo "Data directory already initialized, skipping pg_basebackup."
else
  echo "Running pg_basebackup from primary..."
  rm -rf "$PGDATA"
  mkdir -p "$PGDATA"
  chown postgres:postgres "$PGDATA"
  chmod 700 "$PGDATA"
  PGPASSWORD=rep_pass gosu postgres pg_basebackup \
    -h "$PRIMARY_HOST" \
    -p 5432 \
    -U replicator \
    -D "$PGDATA" \
    -P \
    -Xs \
    -R
  echo "pg_basebackup complete."
fi

echo "Starting PostgreSQL in standby mode..."
exec gosu postgres postgres
