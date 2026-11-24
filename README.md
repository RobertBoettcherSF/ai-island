# AI Island

A small island world in Plain Ada. An AI agent plays it by running the `island` command. A person can play the same world in the browser. The program does not bundle a model or a key.

The island is deterministic. The same commands always do the same thing. It is an independent toy, with ideas inspired by [arXiv 2610.07130](https://arxiv.org/abs/2610.07130) ("Is this machine playing?"). That is not an endorsement.

This version was written with an AI coding assistant, following a Plain Ada style so a later SPARK proof does not need a rewrite. There is no proof in this version.

## Play in the browser

After this is on `main`, the page is [https://robertboettchersf.github.io/ai-island/](https://robertboettchersf.github.io/ai-island/).

A commit-pinned copy is `https://raw.githack.com/RobertBoettcherSF/ai-island/<commit>/docs/index.html`.

The map shows the whole island. Drag to pan and scroll to zoom. Click a creature to see its traits, age, and stomach. A small chart plots population and average traits. **Play**, **Pause**, and **1x / 10x / 100x** run the built-in brains, including while Auto is running. **Auto** starts a run from the seeds in the address bar and the button becomes **Stop**. Stop finishes the current turn, pauses, and downloads `ai-island-run.json` (version, commit, seeds, turns, population, births, deaths, traits at the start and the end, a sample every 100 turns, and the last commands). **Debug** (or the F9 key) downloads a small JSON report with the same seeds. **Sound on** plays a short click; click it to turn sound off. The page follows the reduced-motion setting. The language is English (`en-GB`) only in this version.

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
| `world` | The two seeds, population, births, deaths, and average traits. This does not spend a turn. |

Failure reasons include `blocked`, `nothing here`, `hand full`, `hand empty`, `occupied`, `unknown command`, `bad command`, `no world`, `bad save`, `text too long`, and `text not plain`.

## The island

The grid is 96 by 96, drawn from a fixed seed. `x` increases east and `y` increases south. Both run from 0 to 95. You start at 48,48 facing north, on grass, with an empty hand. The shore is beach, the west is forest, and there is a lake. Berry groves are spread out, so creatures have to move to feed.

Water, rock, and trees block movement. Sand and grass do not. A step off the beach is water, so you stay put.

The stone starts at 47,48. A stick is at 49,48. A shell is at 48,50. Nothing is random.

Twelve other creatures start with you. Each has speed, sight, metabolism, and fertility. A faster creature spends more fullness per turn. Two adults standing next to each other, both above 70 fullness, can have one child. The child's traits are the parents' average plus a small fixed nudge, and both parents lose 30 fullness. Creatures die of starvation or old age. Berries grow back slowly, so the population settles near what the island can feed. You are one more creature under the same stomach rules. `look` lists the creatures you can see. `world` summarises the population.

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

That builds with `-gnat2022 -gnata -gnatwa -gnatwe`, links the runtime statically, and runs a smoke that eats berries, fails to fish without the stick, then fishes with it, checks the hunger countdown, forces one birth, starves one creature, and runs 2000 turns. The long run passes when the population is still alive and an average trait has changed. The same seeds produce the same world after 2000 turns, and a different island seed produces a different island. `ldd bin/island` must not mention `libgnat`.

The browser build is separate and does not download a compiler:

```sh
./tools/build-wasm.sh
```

If AdaWebPack is missing, the script stops. The one-time download, only after you agree to it, is `./tools/get-toolchain.sh`. It installs into `~/toolchains/adawebpack-24`.

The zip for a local run:

```sh
make zip
```

Unpack `zips/ai-island-v0.3.1.zip`. It becomes `ai-island-v0.3.1/`.

```sh
cd ai-island-v0.3.1
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
