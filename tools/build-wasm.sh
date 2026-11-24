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
    ../../src/island-rng.adb \
    ../../src/island-map.adb \
    ../../src/island-stomach.adb \
    ../../src/island-folk.adb \
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
    --export=island_reset_seeds \
    --export=island_island_seed \
    --export=island_pop_seed \
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
    --export=island_simulate \
    --export=island_population \
    --export=island_births \
    --export=island_deaths \
    --export=island_turn \
    --export=island_fullness \
    --export=island_average \
    --export=island_folk_max \
    --export=island_folk_alive \
    --export=island_folk_x \
    --export=island_folk_y \
    --export=island_folk_age \
    --export=island_folk_full \
    --export=island_folk_speed \
    --export=island_folk_sight \
    --export=island_folk_meta \
    --export=island_folk_fert \
    --export=island_sample_count \
    --export=island_sample \
    --export=island_paint \
    --export=island_map_ptr \
    --export=island_group_count \
    --export=island_group_pop \
    --export=island_group_births \
    --export=island_group_deaths \
    --export=island_group_homes \
    --export=island_group_avg \
    --export=island_group_extinct \
    --export=island_group_cause \
    --export=island_home_max \
    --export=island_home_used \
    --export=island_home_x \
    --export=island_home_y \
    --export=island_home_group \
    --export=island_home_kind \
    --export=island_home_residents \
    --export=island_folk_group \
    --export=island_folk_home \
    --export=island_folk_scout \
    --export=island_folk_marker \
    --export=island_group_trust \
    --export=island_group_trades \
    --export=island_group_in \
    --export=island_group_out \
    --export=island_group_allele \
    --export=island_home_store \
    --export=island_river_len \
    --export=island_river_x \
    --export=island_river_y \
    --export=island_trail_count \
    --export=island_trail_x \
    --export=island_trail_y \
    --export=island_road_count \
    --export=island_road_x \
    --export=island_road_y \
    --export=island_market_count \
    --export=island_market_x \
    --export=island_market_y \
    --export=island_market_trades \
    --export=island_meetings \
    --export=island_thirst \
    --export=island_tile_height \
    --export=island_rejections \
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
