#!/usr/bin/env python3
"""Embed the wasm module into the single-file page and write version.txt."""
import base64
import pathlib
import sys

wasm, template, out, stamp, commit = sys.argv[1:6]
page = pathlib.Path(template).read_text()
page = page.replace("__WASM_BASE64__", base64.b64encode(pathlib.Path(wasm).read_bytes()).decode())
page = page.replace("__STAMP__", stamp)
page = page.replace("__COMMIT__", commit)
dest = pathlib.Path(out)
dest.parent.mkdir(parents=True, exist_ok=True)
dest.write_text(page)
version = dest.parent / "version.txt"
version.write_text(stamp + "\n")
print(f"wrote {dest} and {version}")
