#!/usr/bin/env python3
"""CLI smoke for hunger and food. One process per command, state in the save."""
import json, subprocess, sys, tempfile, os

bin_path = sys.argv[1]


def play(save, *args):
    proc = subprocess.run([bin_path, "--save", save, *args], capture_output=True, text=True)
    try:
        body = json.loads(proc.stdout)
    except json.JSONDecodeError:
        sys.exit("not json: " + proc.stdout)
    return proc.returncode, body


def main():
    tmp = tempfile.mkdtemp()
    save = os.path.join(tmp, "island.save")
    code, body = play(save, "look")
    if code == 0 or body.get("reason") != "no world":
        sys.exit("missing world should fail")

    code, body = play(save, "new")
    if not body.get("ok") or body.get("fullness") != 100 or body.get("turn") != 0:
        sys.exit("new: " + json.dumps(body))
    if body.get("hunger") != "ok":
        sys.exit("new hunger")

    # Each look is one action, so fullness falls by 1. 71 looks reach 29.
    last = None
    for _ in range(71):
        code, last = play(save, "look")
        if code != 0 or not last.get("ok"):
            sys.exit("look failed")
    if last["turn"] != 71 or last["fullness"] != 29 or last["hunger"] != "hungry":
        sys.exit("countdown: " + json.dumps({k: last[k] for k in ("turn", "fullness", "hunger")}))
    seen = last["seen"]
    if not any(cell.get("food") == "berries" for cell in seen):
        sys.exit("look did not list berries")

    code, body = play(save, "move", "N")
    code, body = play(save, "move", "E")
    before = body["fullness"]
    code, body = play(save, "eat")
    if not body.get("ok") or body.get("food") != "berries":
        sys.exit("berries: " + json.dumps(body))
    if body["fullness"] != before + 24:
        sys.exit("berry gain %s -> %s" % (before, body["fullness"]))

    play(save, "move", "S")
    play(save, "move", "S")
    for _ in range(12):
        play(save, "move", "E")
    code, body = play(save, "eat")
    if code == 0 or body.get("reason") != "need a stick":
        sys.exit("fish without stick: " + json.dumps(body))

    for _ in range(11):
        play(save, "move", "W")
    play(save, "move", "N")
    code, body = play(save, "pick")
    if body.get("hand") != "stick":
        sys.exit("pick stick: " + json.dumps(body))
    play(save, "move", "S")
    for _ in range(11):
        play(save, "move", "E")
    before = play(save, "look")[1]["fullness"]
    # look spent a turn; eat is the next command. Re-read by eating now.
    code, body = play(save, "eat")
    if not body.get("ok") or body.get("food") != "fish":
        sys.exit("fish: " + json.dumps(body))
    if body["fullness"] <= before:
        sys.exit("fish did not feed %s -> %s" % (before, body["fullness"]))
    print("food smoke ok")


if __name__ == "__main__":
    main()
