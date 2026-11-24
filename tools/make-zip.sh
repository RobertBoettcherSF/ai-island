#!/bin/sh
# Build zips/ai-island-v<VERSION>.zip with the static Linux binary and sources.
# The zip unpacks to ai-island-v<VERSION>/.
set -e
cd "$(dirname "$0")/.."
VER=$(tr -d ' \n' < VERSION)
NAME=ai-island-v$VER
if [ ! -x bin/island ]; then
  echo "Run make first so bin/island exists." >&2
  exit 1
fi
STAGE=$(mktemp -d)
mkdir -p "zips" "$STAGE/$NAME"
cp README.md LICENSE VERSION Makefile island.gpr "$STAGE/$NAME/"
cp -a src tests web tools .github "$STAGE/$NAME/"
cp bin/island "$STAGE/$NAME/island"
strip "$STAGE/$NAME/island"
chmod +x "$STAGE/$NAME/island" "$STAGE/$NAME/tests/smoke.sh" \
  "$STAGE/$NAME/tools/build-wasm.sh" "$STAGE/$NAME/tools/get-toolchain.sh" \
  "$STAGE/$NAME/tools/make-zip.sh"
rm -rf "$STAGE/$NAME/obj" "$STAGE/$NAME/bin" "$STAGE/$NAME/zips"
find "$STAGE/$NAME" -name '*.save' -delete
rm -f "$STAGE/$NAME/docs/index.html" "$STAGE/$NAME/docs/version.txt"
(
  cd "$STAGE"
  zip -r -q "$OLDPWD/zips/$NAME.zip" "$NAME"
)
rm -rf "$STAGE"
ls -l "zips/$NAME.zip"
