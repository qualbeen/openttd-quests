#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION=$(grep 'function GetVersion' "$SCRIPT_DIR/gamescript/info.nut" | grep -o '[0-9]*')

OUTDIR="$SCRIPT_DIR/dist"
mkdir -p "$OUTDIR"

tar -czf "$OUTDIR/openttd-quests-v${VERSION}.tar.gz" -C "$SCRIPT_DIR" gamescript/ --transform 's/^gamescript/openttd-quests/'

echo "Package created: $OUTDIR/openttd-quests-v${VERSION}.tar.gz"
