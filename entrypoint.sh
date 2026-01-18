#!/bin/bash
set -e

echo "Waiting for database..."
while ! pg_isready -h db -U postgres -q 2>/dev/null; do
  sleep 1
done

echo "Running migrations..."
/app/bin/hytalix eval "Hytalix.Release.migrate"

echo "Starting Hytalix..."
exec /app/bin/hytalix start
