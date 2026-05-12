#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
GS_DIR="$SCRIPT_DIR/gamescript"

case "$(uname)" in
    Darwin) DEST="$HOME/Documents/OpenTTD/game/openttd-quests" ;;
    Linux)  DEST="$HOME/.openttd/game/openttd-quests" ;;
    *)      echo "Unsupported OS. Copy gamescript/ to your OpenTTD game/ directory manually."; exit 1 ;;
esac

mkdir -p "$(dirname "$DEST")"
rm -rf "$DEST"
cp -r "$GS_DIR" "$DEST"

echo "Installed to $DEST"
echo "Start OpenTTD → New Game → AI/Game Script Settings → select 'OpenTTD Quests'"
