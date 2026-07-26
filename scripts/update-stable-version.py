#!/usr/bin/env python3
"""Update stable EX4100 image references after a validated release build."""

from __future__ import annotations

import re
import sys
from pathlib import Path

IMAGE_REPOSITORY = "ovelayos/pihole-wd-ex4100"
VERSIONED_IMAGE_PATTERN = re.compile(
    rf"{re.escape(IMAGE_REPOSITORY)}:[0-9]{{4}}\.[0-9]{{2}}\.[0-9]+-ex4100-r[0-9]+"
)
REPOSITORY_TAG_PATTERN = re.compile(
    r"(?<!:)[0-9]{4}\.[0-9]{2}\.[0-9]+-ex4100-r[0-9]+"
)
UPSTREAM_TAG_ARGUMENT_PATTERN = re.compile(
    r"(?m)^(\s*-PiholeTag\s+)[0-9]{4}\.[0-9]{2}\.[0-9]+(\s*`?)$"
)


def replace_required(path: Path, pattern: re.Pattern[str], replacement: str) -> int:
    original = path.read_text(encoding="utf-8")
    updated, count = pattern.subn(replacement, original)
    if count == 0:
        raise RuntimeError(f"Expected version reference was not found in {path}")
    if updated != original:
        path.write_text(updated, encoding="utf-8")
    return count


def main() -> int:
    if len(sys.argv) != 3:
        print(
            "Usage: update-stable-version.py <repository-tag> <upstream-tag>",
            file=sys.stderr,
        )
        return 2

    repository_tag = sys.argv[1]
    upstream_tag = sys.argv[2]

    if not re.fullmatch(r"[0-9]{4}\.[0-9]{2}\.[0-9]+-ex4100-r[0-9]+", repository_tag):
        raise ValueError(f"Invalid repository tag: {repository_tag}")
    if not re.fullmatch(r"[0-9]{4}\.[0-9]{2}\.[0-9]+", upstream_tag):
        raise ValueError(f"Invalid upstream tag: {upstream_tag}")

    versioned_image = f"{IMAGE_REPOSITORY}:{repository_tag}"

    replace_required(
        Path("compose/portainer-stack.yml"),
        VERSIONED_IMAGE_PATTERN,
        versioned_image,
    )
    replace_required(
        Path(".env.example"),
        VERSIONED_IMAGE_PATTERN,
        versioned_image,
    )
    replace_required(Path("README.md"), VERSIONED_IMAGE_PATTERN, versioned_image)
    replace_required(Path("README.md"), REPOSITORY_TAG_PATTERN, repository_tag)
    replace_required(
        Path("README.md"),
        UPSTREAM_TAG_ARGUMENT_PATTERN,
        rf"\g<1>{upstream_tag}\g<2>",
    )

    print(f"Stable references now point to {versioned_image}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
