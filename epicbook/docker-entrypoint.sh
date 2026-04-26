#!/bin/sh
set -e

echo "================================================"
echo " EpicBook Container Starting"
echo "================================================"
echo "NODE_ENV: $NODE_ENV"
echo "DB_HOST:  $DB_HOST"
echo "DB_PORT:  $DB_PORT"
echo "DB_NAME:  $DB_NAME"
echo "DB_USER:  $DB_USER"
echo "================================================"

# Wait for MySQL to accept connections
echo "Waiting for MySQL at $DB_HOST:$DB_PORT..."
until nc -z "$DB_HOST" "$DB_PORT" 2>/dev/null; do
  echo "  MySQL not ready — retrying in 3s"
  sleep 3
done
echo "MySQL is ready."

# Seed database only if tables do not exist yet
# This makes the entrypoint idempotent — safe to restart
TABLE_COUNT=$(mysql -h "$DB_HOST" -P "$DB_PORT" \
  -u "$DB_USER" -p"$DB_PASSWORD" \
  "$DB_NAME" -e "SHOW TABLES;" 2>/dev/null | wc -l)

if [ "$TABLE_COUNT" -le 1 ]; then
  echo "No tables found — running schema and seed scripts..."

  echo "  Applying schema..."
  mysql -h "$DB_HOST" -P "$DB_PORT" \
    -u "$DB_USER" -p"$DB_PASSWORD" \
    "$DB_NAME" < /app/db/BuyTheBook_Schema.sql

  echo "  Seeding authors..."
  mysql -h "$DB_HOST" -P "$DB_PORT" \
    -u "$DB_USER" -p"$DB_PASSWORD" \
    "$DB_NAME" < /app/db/author_seed.sql

  echo "  Seeding books..."
  mysql -h "$DB_HOST" -P "$DB_PORT" \
    -u "$DB_USER" -p"$DB_PASSWORD" \
    "$DB_NAME" < /app/db/books_seed.sql

  echo "Database seeded successfully."
else
  echo "Tables already exist — skipping seed (idempotent restart)."
fi

echo "Starting EpicBook application..."
exec "$@"
