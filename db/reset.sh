#!/usr/bin/env bash
# Rebuild the database from scratch: drop it, recreate it, then run db/0*.sql in numeric order.
set -euo pipefail
shopt -s nullglob
cd "$(dirname "$0")/.."

set -a; . ./.env; set +a
export MYSQL_PWD="$DB_PASSWORD"
mysql_cmd=(mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" --default-character-set=utf8mb4)

"${mysql_cmd[@]}" -e "DROP DATABASE IF EXISTS \`$DB_NAME\`;
  CREATE DATABASE \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;"

for f in db/0*.sql; do
  echo "-> $f"
  "${mysql_cmd[@]}" "$DB_NAME" < "$f"
done
echo "Reset complete: $DB_NAME"
