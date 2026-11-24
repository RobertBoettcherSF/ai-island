#!/usr/bin/env python3
"""CLI smoke for hunger, food, and the population summary."""
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
    if body.get("hunger") != "ok" or body.get("x") != 48:
        sys.exit("new start: " + json.dumps(body))

    code, body = play(save, "world")
    if not body.get("ok") or body.get("population") != 13 or body.get("births") != 0:
        sys.exit("world: " + json.dumps(body))

    code, body = play(save, "move", "N")
    if not body.get("ok") or body.get("fullness") != 99:
        sys.exit("move: " + json.dumps(body))
    code, body = play(save, "eat")
    if not body.get("ok") or body.get("food") != "berries":
        sys.exit("berries: " + json.dumps(body))

    play(save, "move", "S")
    play(save, "move", "W")
    play(save, "move", "W")
    code, body = play(save, "eat")
    if code == 0 or body.get("reason") != "need a stick":
        sys.exit("fish without stick: " + json.dumps(body))

    play(save, "move", "E")
    play(save, "move", "E")
    play(save, "move", "E")
    code, body = play(save, "pick")
    if body.get("hand") != "stick":
        sys.exit("pick stick: " + json.dumps(body))
    play(save, "move", "W")
    play(save, "move", "W")
    play(save, "move", "W")
    code, body = play(save, "eat")
    if not body.get("ok") or body.get("food") != "fish":
        sys.exit("fish: " + json.dumps(body))

    save2 = os.path.join(tmp, "countdown.save")
    code, body = play(save2, "new")
    code, body = play(save2, "look")
    if "creatures" not in body or not any(cell.get("food") == "berries" for cell in body["seen"]):
        sys.exit("look did not list berries or creatures")
    last = body
    for _ in range(70):
        code, last = play(save2, "look")
        if code != 0 or not last.get("ok"):
            sys.exit("look failed")
    if last["turn"] != 71 or last["fullness"] != 29 or last["hunger"] != "hungry":
        sys.exit("countdown: " + json.dumps({k: last[k] for k in ("turn", "fullness", "hunger")}))

    save3 = os.path.join(tmp, "seeds.save")
    code, body = play(save3, "new")
    code, body = play(save3, "world")
    if body.get("island") != 539365668 or body.get("pop") != 539365668:
        sys.exit("default seeds: " + json.dumps(body))
    code, body = play(save3, "new", "--island", "42", "--pop", "7")
    code, body = play(save3, "world")
    if body.get("island") != 42 or body.get("pop") != 7 or body.get("population") != 13:
        sys.exit("custom seeds: " + json.dumps(body))
    print("food smoke ok")


if __name__ == "__main__":
    main()
