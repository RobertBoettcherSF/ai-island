#!/bin/sh
# Compile the island core to WebAssembly and embed it in docs/index.html.
# Stops if AdaWebPack is missing. This script never downloads it.
set -e
cd "$(dirname "$0")/.."
AW=${ADAWEBPACK:-$HOME/toolchains/adawebpack-24}
T=$AW/usr
if [ ! -x "$T/bin/llvm-gcc" ]; then
  echo "AdaWebPack is not at $AW." >&2
  echo "Set ADAWEBPACK, or run tools/get-toolchain.sh after you agree to the download." >&2
  exit 1
fi
LD=$(command -v wasm-ld || true)
if [ -z "$LD" ]; then
  echo "wasm-ld is not installed (package lld)." >&2
  exit 1
fi
export LD_LIBRARY_PATH="$AW/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
rm -rf obj/wasm
mkdir -p obj/wasm docs
(
  cd obj/wasm
  for F in \
    ../../src/island-map.adb \
    ../../src/island-stomach.adb \
    ../../src/island-world.adb \
    ../../src/island-text.adb \
    ../../src/island-api.adb \
    ../../src/wasm/last_chance.adb
  do
    "$T/bin/llvm-gcc" -c --target=wasm32 -O2 -gnat2022 -gnatwa -gnatwe -gnatp \
      --RTS="$T/lib/rts-native" -I../../src "$F"
  done
  ar x "$T/lib/rts-native/adalib/libgnat.a" s-memcop.o s-memmov.o s-memset.o
  "$LD" --no-entry --allow-undefined --strip-all \
    --export=island_reset \
    --export=island_exec \
    --export=island_command_ptr \
    --export=island_reply_ptr \
    --export=island_reply_len \
    --export=island_cell \
    --export=island_object \
    --export=island_food \
    --export=island_agent_x \
    --export=island_agent_y \
    --export=island_facing \
    --export=island_hand \
    --export=island_width \
    --export=island_height \
    --export=memory \
    --export=__gnat_last_chance_handler \
    -z stack-size=1048576 --initial-memory=16777216 \
    -o island.wasm ./*.o
)
VER=$(tr -d ' \n' < VERSION)
WHEN=$(TZ=Europe/Berlin date +%Y%m%d-%H%M)
SHA=$(git rev-parse --short=7 HEAD 2>/dev/null || echo unknown)
DIRTY=""
if [ -n "$(git status --porcelain | grep -v -E 'docs/index.html|docs/version.txt' || true)" ]; then
  DIRTY="+"
fi
STAMP="v${VER} b${WHEN} ${SHA}${DIRTY}"
python3 tools/embed.py obj/wasm/island.wasm web/template.html docs/index.html "$STAMP" "$SHA"
echo "Built docs/index.html ($STAMP, $(wc -c < obj/wasm/island.wasm) bytes of WebAssembly)"
