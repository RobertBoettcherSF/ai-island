#!/bin/sh
# CLI smoke: each command is a fresh process, so the save file has to work.
# Also checks the in-memory API run prints the same JSON.
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
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
SAVE=$TMP/island.save

expect_fail() {
  name=$1
  shift
  if "$BIN" --save "$SAVE" "$@" > "$TMP/out"; then
    echo "$name should have failed" >&2
    exit 1
  fi
  diff -u "tests/expected/$name" "$TMP/out"
}

expect_ok() {
  name=$1
  shift
  "$BIN" --save "$SAVE" "$@" > "$TMP/out"
  diff -u "tests/expected/$name" "$TMP/out"
}

expect_fail 00-no-world.json look
expect_ok 01-new.json new
expect_ok 02-look.txt --text look
expect_ok 03-look.json look
expect_ok 04-move.json move N
expect_ok 05-pick.json pick
expect_ok 06-place.json place
expect_ok 07-look.json look
expect_fail 08-unknown.json fly

"$SMOKE" > "$TMP/api"
cat tests/expected/01-new.json \
    tests/expected/03-look.json \
    tests/expected/04-move.json \
    tests/expected/05-pick.json \
    tests/expected/06-place.json \
    tests/expected/07-look.json > "$TMP/want"
diff -u "$TMP/want" "$TMP/api"
echo "smoke ok"
