#!/usr/bin/env bash
set -euo pipefail

PIHOLE_TAG="${1:-2026.07.2}"
WORKDIR="${2:-.build}"

rm -rf "$WORKDIR"
git clone --depth 1 --branch "$PIHOLE_TAG" https://github.com/pi-hole/docker-pi-hole.git "$WORKDIR"

DOCKERFILE="$WORKDIR/src/Dockerfile"

python3 "$(dirname "$0")/patch_source.py" "$WORKDIR"

printf 'Prepared Pi-hole %s in %s\n' "$PIHOLE_TAG" "$WORKDIR"
printf 'Base image: '
grep -m1 '^FROM alpine:' "$DOCKERFILE"
printf 'Process package: '
grep -m1 -E '^[[:space:]]+procps( |\\)' "$DOCKERFILE" || true
