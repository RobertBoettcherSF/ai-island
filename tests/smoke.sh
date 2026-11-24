#!/bin/sh
# CLI smoke: berries, a failed cast, a fish, and the hunger countdown.
# The in-memory smoke binary runs the same rules with checks on.
set -eu
cd "$(dirname "$0")/.."
BIN=./bin/island
SMOKE=./obj/tests/smoke
if [ ! -x "$BIN" ]; then
  echo "missing $BIN" >&2
  exit 1
fi
if [ ! -x "$SMOKE" ]; then
  echo "missing $SMOKE" >&2
  exit 1
fi
if ldd "$BIN" 2>/dev/null | grep -q libgnat; then
  echo "libgnat is dynamically linked" >&2
  exit 1
fi
"$SMOKE"
python3 tests/check_food.py "$BIN"
echo "smoke ok"
