#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "Generating quest definitions from YAML..."
python3 "$SCRIPT_DIR/scripts/generate_quest_defs.py" || { echo "Error: Quest generation failed."; exit 1; }

VERSION=$(grep 'function GetVersion' "$SCRIPT_DIR/gamescript/info.nut" | grep -o '[0-9]*')

OUTDIR="$SCRIPT_DIR/dist"
mkdir -p "$OUTDIR"

tar -czf "$OUTDIR/openttd-quests-v${VERSION}.tar.gz" -C "$SCRIPT_DIR" gamescript/ --transform 's/^gamescript/openttd-quests/'

echo "Package created: $OUTDIR/openttd-quests-v${VERSION}.tar.gz"
