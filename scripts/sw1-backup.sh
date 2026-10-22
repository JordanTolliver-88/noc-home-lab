#!/usr/bin/env bash
# Copy the newest SW1 config archive from TFTP into the repo,
# redact secrets, and commit only if the config changed.
set -euo pipefail

SRC_DIR=/srv/tftp
REPO="$HOME/noc-home-lab"
DEST="$REPO/configs/sw1-running.txt"

latest=$(ls -t "$SRC_DIR"/sw1-config* 2>/dev/null | head -n1 || true)
if [ -z "$latest" ]; then
  echo "$(date): no archive files found in $SRC_DIR"
  exit 1
fi
if [ ! -s "$latest" ]; then
  echo "$(date): newest archive $latest is empty; skipping"
  exit 1
fi

sed -E \
  -e 's/\r//' \
  -e 's/(secret [0-9]) .*/\1 <REDACTED>/' \
  -e 's/(password [0-9]) .*/\1 <REDACTED>/' \
  -e '/^ntp clock-period/d' \
  -e '/^! (Last configuration change|NVRAM config last updated)/d' \
  -e '/^Current configuration :/d' \
  "$latest" > "$DEST"

cd "$REPO"
if git diff --quiet -- "$DEST"; then
  echo "$(date): no config changes"
  exit 0
fi

git add "$DEST"
git commit -m "SW1 config backup $(date +%F)"
git push || echo "$(date): push failed; commit saved locally, run 'git push' later"


