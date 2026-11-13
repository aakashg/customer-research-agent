#!/bin/bash
# Reset to a clean demo state between takes.
#   1. Restore customers.csv from customers.seed.csv (or the example roster).
#   2. Clear conversation logs and reports.
#   3. Trash this campaign's mail from the brand mailbox (/reset-gmail),
#      or, in dry run (DRY_RUN=1), clear outbox/ instead. No Gmail is touched.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

seed="customers.seed.csv"
[ -f "$seed" ] || seed="customers.example.csv"
cp "$seed" customers.csv
echo "Restored customers.csv from $seed."

find conversations reports -type f ! -name .gitkeep -delete
echo "Cleared conversations/ and reports/."

if [ "${DRY_RUN:-0}" = "1" ]; then
  mkdir -p outbox
  find outbox -type f ! -name .gitkeep -delete
  echo "Dry run: cleared outbox/. Gmail was not touched."
  exit 0
fi

echo "Clearing campaign mail from the brand mailbox..."
claude -p "/reset-gmail"

echo "Note: the inbox you reply from as a test customer isn't touched. Re-seed replies there by hand."
