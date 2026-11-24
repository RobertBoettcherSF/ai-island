# AI Island

A small island world in Plain Ada. An AI agent plays it by running the `island` command. A person can play the same world in the browser. The program does not bundle a model or a key.

The island is deterministic. The same commands always do the same thing. It is an independent toy, with ideas inspired by [arXiv 2610.07130](https://arxiv.org/abs/2610.07130) ("Is this machine playing?"). That is not an endorsement.

This version was written with an AI coding assistant, following a Plain Ada style so a later SPARK proof does not need a rewrite. There is no proof in this version.

## Play in the browser

After this is on `main`, the page is [https://robertboettchersf.github.io/ai-island/](https://robertboettchersf.github.io/ai-island/).

A commit-pinned copy is `https://raw.githack.com/RobertBoettcherSF/ai-island/<commit>/docs/index.html`.

The page shows the status line, the map, the legends, the info box, the chart, the two seeds, and the buttons. Drag to pan and scroll to zoom. Click a creature or a home. The chart has one line per group, and a small mark when a trade or a migrant is recorded. Rivers, trails, roads, and markets are drawn on the map. **Play**, **Pause**, and **1x / 10x / 100x** run the built-in brains. **Auto** starts a run and becomes **Stop**. Stop downloads `ai-island-run.json`, which adds thirst, meetings, trail length, road length, markets, and trades at each market. **Debug** opens the command line and the log. The F9 key downloads the short report. **Sound on** plays a short click. The page follows the reduced-motion setting. The language is English (`en-GB`) only in this version.

The island seed sets the ground and the food. The population seed sets the starting creatures. Both default to `539365668`, which is the 0.3 island. Change the numbers, or press **Random**, and the address becomes `?island=42&pop=7`. Opening that address starts the same island.

## Play in the terminal

```sh
make
./bin/island new
./bin/island new --island 42 --pop 7
./bin/island look
./bin/island world
./bin/island move N
./bin/island pick
./bin/island place
./bin/island say "hello"
```

Each command prints one JSON object and then exits. `ok` is true or false. On failure, read `reason` and try something else. Add `--text` before the command for a short English sentence:

```sh
./bin/island --text look
```

The world is kept in `island.save` in the current directory. `new` starts again and replaces that file. Another directory is `--save path`.

`make` uses the `gcc` that is GNAT. On a machine where the Ada compiler has another name:

```sh
make ADA_DRIVER=gcc-12
```

## Commands

| Command | What it does |
| --- | --- |
| `new` | Start the island again. `new --island N --pop M` chooses the two seeds. |
| `look` | Where you are, which way you face, what is in your hand, the squares you can see, and the creatures in that view. |
| `move N` | Step north, east, south, or west. `E`, `S`, and `W` work the same way. `north` is also accepted. |
| `pick` | Pick up the stone, stick, or shell on your square. Your hand holds one thing. |
| `place` | Put the thing in your hand on your square, if the square is empty. |
| `eat` | Eat the berries or the fish in front of you. Fish need the stick. |
| `say "text"` | Remember a short note. Plain letters, digits, and spaces, up to 80 characters. |
| `gather` | Pick up one stick, one stone, or a portion of berries to carry. |
| `build` | Spend 5 sticks and 3 stones to build a hut where you stand. |
| `feed` | Give carried berries to a child in the home where you stand. |
| `trade` | Swap surplus goods with a creature from another group beside you. |
| `world` | The two seeds, population, groups, and homes. This does not spend a turn. |

Failure reasons include `blocked`, `nothing here`, `hand full`, `hand empty`, `occupied`, `unknown command`, `bad command`, `no world`, `bad save`, `text too long`, and `text not plain`.

## The island

The default map is Medium, 129 by 129, the same sizes Dwarf Fortress uses: Pocket 17, Smaller 33, Small 65, Medium 129, Large 257. `x` increases east and `y` increases south. You start at 48,48 facing north, on grass, with an empty hand. The island seed builds a dome so the interior stays above the sea, then rainfall, drainage, and ridgelines. The sea is whatever low ground touches the edge. At most two lakes are kept, and a lake that would overflow becomes marsh. Springs and fish are chosen from the seed. Temperature is warmer toward the equator, which lies on the south edge unless you move the pole. Twelve land biomes follow height, rain, drainage, and temperature. Desert makes people thirstier, tundra makes them hungrier, and beaches yield salt. A map that fails a check is rejected; the reason codes are in the run file and the F9 report. `new --size medium --pole north --preset balanced` sets the same choices as `?size=3&pole=0&preset=0`.

Water, rock, and trees block movement. Sand and grass do not. A step off the beach is water, so you stay put.

The stone starts at 47,48. A stick is at 49,48. A shell is at 48,50. Nothing is random.

Uphill steps cost more and downhill steps cost less. A pass is cheaper than a climb. Walking wears a tile and clears foliage; a worn tile is quicker, so people prefer it and the path deepens, and an unused trail slowly grows back. A deeply worn route between a home and a market becomes a road. The run file records the longest worn trail and its wear. Hungry people move only toward ground that has more food. A busy market draws a new home, and that settlement has its own title: hamlet, village, town, city, or metropolis, from the number of residents. Groups have names and values. A migrant keeps their values. Relations are no contact, peace, alliance, or estranged. The map is shaded by height, and **Height** (behind **Debug**) draws the elevation. The info box shows the height of the tile you click.

Twelve other creatures start with you, three in each group, beside those homes. You are in group 1. Speed, sight, metabolism, and fertility each come from two alleles. A child inherits one allele from each parent, and the visible trait is their average. A colour allele is dominant. Low metabolism saves food and also slows the creature, so it is not free. A scout with wide sight follows the river downstream and can meet another group. A meeting can trade, and trust lets a creature migrate or a pair from two groups have a child. On the way home a traveller leaves a scent. The scent fades, and another pass strengthens it. Creatures prefer a marked tile, so a path appears. A strong trail can be paved with sticks and stones into a road, which is faster and wears out if nobody uses it. Where two strong trails cross, a market opens. Surplus sticks, stones, and food change hands there, and a busy market draws a new hut. `gather`, `build`, `feed`, and `trade` are the player's extra commands. `world` lists the groups and the homes.

## Plug in your AI

The island does not call a model. A terminal coding agent (Claude Code, Codex, Kimi Code, Cursor, and the same kind of tool) can play with no API key: it only has to run the commands below. Paste this prompt.

```
You are playing a small island by running the command-line program `island` in this repository. Do not modify the program, and do not invent a map. Play only by executing commands.

If ./bin/island does not exist, run `make` first. GNAT and gprbuild must already be installed. Then play only with ./bin/island.

Commands, one per run:

./bin/island new --island 42 --pop 7
./bin/island look
./bin/island move N
./bin/island move E
./bin/island move S
./bin/island move W
./bin/island pick
./bin/island place
./bin/island eat
./bin/island gather
./bin/island build
./bin/island feed
./bin/island world
./bin/island say "a short note"

Each command prints one JSON object. Trust `ok`. On failure, read `reason` and try a different command. `look` shows your x, y, facing, hand, fullness, hunger, turn, the squares you can see, and the nearby creatures. `world` shows both seeds, the population, and the average traits, and does not spend a turn. `new --island N --pop M` starts that island. The defaults are island 539365668 and pop 539365668. You can carry one object. Water, rock, and trees block movement. Sand and grass do not. Berries are eaten from the bush in front of you. Fish need the stick. Hunger falls every action, faster while you carry something, and faster if your metabolism is high. At 0 you are weak, and after 20 more turns without food you collapse. Other creatures eat, look for a mate, and can have children. State is kept in `island.save` in the current directory. Start with `./bin/island new` if a command says `no world`.

Your goal is to stay alive. Do not follow a script. Eat when you need to, and keep going.
```

Optional, and not used by the island itself: a local model or an API can sit in front of the same commands. Set `ISLAND_MODEL` to a program you supply. It reads the last JSON reply on stdin and prints the next command on stdout. No key is built in. If `ISLAND_MODEL` is unset, the loop does nothing.

```python
import json, os, subprocess
bin = os.environ.get("ISLAND", "./bin/island")
model = os.environ.get("ISLAND_MODEL")  # your program, not part of this repo
reply = subprocess.check_output([bin, "new"], text=True)
print(reply, end="")
for _ in range(8):
    if not model:
        break
    nxt = subprocess.check_output(model, input=reply, text=True, shell=True).strip()
    reply = subprocess.check_output([bin, *nxt.split()], text=True)
    print(nxt)
    print(reply, end="")
```

## Build and test

From a fresh clone, with GNAT and gprbuild on `PATH` (`gcc` must be the Ada compiler):

```sh
make test
```

That builds with `-gnat2022 -gnata -gnatwa -gnatwe`, links the runtime statically, and runs a short smoke. Every river steps downhill and ends in water, the same seed rebuilds the same map, and the default seeds produce a meeting and a trade within 3000 turns. Ten thousand draws from the SplitMix32 generator fall evenly across ten buckets, and a second stream with the same seed matches. The same checks cover berries, fish, a birth, a feeding, a full home, a meeting trade, a migration, a cross-group birth, a 1:2:1 colour cross, one starvation, and 2000 turns twice with the same seeds. `ldd bin/island` must not mention `libgnat`.

Numbers in the rules come from `Island.Rng`. Terrain uses the island seed. Folk use a stream started from the population seed. Nothing reads the clock.

In 0.3.1 the population sat at 35 because the world had 36 creature slots and the player's slot was never given to anyone else. Births now wait for room in a home.

The browser build is separate and does not download a compiler:

```sh
./tools/build-wasm.sh
```

If AdaWebPack is missing, the script stops. The one-time download, only after you agree to it, is `./tools/get-toolchain.sh`. It installs into `~/toolchains/adawebpack-24`.

The zip for a local run:

```sh
make zip
```

Unpack `zips/ai-island-v0.4.zip`. It becomes `ai-island-v0.4/`.

```sh
cd ai-island-v0.4
./island new --island 42 --pop 7
./island look
./island world
```

To rebuild that tree from source: `make test`.

## Core

One world, two hosts. `src/island-world.adb` is the rules. `src/island_cli.adb` is the terminal. `src/island-api.adb` is the integer interface the browser calls. The web page only draws, plays the click, and shows the reply.

In the core:

- no tasking
- no heap, allocators, or unbounded containers
- no exception handlers
- no `Text_IO` or other file units
- fixed-size arrays and records only
- no access types
- contracts on the commands (`Pre` / `Post`) and ranged subtypes
- no hidden random source and no clock in the rules

The terminal and the wasm last-chance handler are outside that core. Native builds keep checks on (`-gnata`). The wasm build uses `-gnatp`, and `make test` runs the same sources with checks on.

Later pieces (replay, physics, bird sound, MCP) can add a command or a host. They should not grow a second copy of the map.

The page is English only in this version. Sound, reduced motion, the version stamp, and the Debug report are included.
