#!/usr/bin/env python3
from __future__ import annotations

import pathlib
import re
import sys


def normalize_lf(path: pathlib.Path) -> None:
    data = path.read_bytes()
    normalized = data.replace(b"\r\n", b"\n").replace(b"\r", b"\n")
    if normalized != data:
        path.write_bytes(normalized)


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: patch_source.py <docker-pi-hole-source>", file=sys.stderr)
        return 2

    root = pathlib.Path(sys.argv[1]).resolve()
    dockerfile = root / "src" / "Dockerfile"
    if not dockerfile.is_file():
        raise FileNotFoundError(f"Dockerfile not found: {dockerfile}")

    for path in root.rglob("*"):
        if path.is_file() and (path.suffix == ".sh" or path.name == "Dockerfile"):
            normalize_lf(path)

    text = dockerfile.read_text(encoding="utf-8")
    text, count = re.subn(r"^FROM alpine:[^\s]+", "FROM alpine:3.17.10", text, count=1, flags=re.MULTILINE)
    if count != 1:
        raise RuntimeError("Could not replace Alpine base image")

    text = text.replace("procps-ng", "procps")

    marker = "# WD EX4100 compatibility: normalize shell scripts to LF"
    entrypoint = 'ENTRYPOINT ["start.sh"]'
    run_block = """# WD EX4100 compatibility: normalize shell scripts to LF
RUN find /usr/bin /usr/local/bin /opt/pihole -type f \\
    \\( -name \"*.sh\" -o -name \"start.sh\" -o -name \"bash_functions.sh\" \\) \\
    -exec sed -i 's/\\r$//' {} \\;

"""

    if marker not in text:
        if entrypoint not in text:
            raise RuntimeError("Official entrypoint not found in Dockerfile")
        text = text.replace(entrypoint, run_block + entrypoint, 1)

    dockerfile.write_text(text, encoding="utf-8", newline="\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
