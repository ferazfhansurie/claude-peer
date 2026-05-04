#!/usr/bin/env bash
# claude-peer installer — drops the script into ~/.local/bin
set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/ferazfhansurie/claude-peer/main"
DEST_DIR="${CLAUDE_PEER_INSTALL_DIR:-$HOME/.local/bin}"
DEST="$DEST_DIR/claude-peer"

mkdir -p "$DEST_DIR"

echo "→ fetching claude-peer..."
curl -fsSL "$REPO_RAW/bin/claude-peer" -o "$DEST"
chmod +x "$DEST"

echo "✓ installed: $DEST"

case ":$PATH:" in
  *":$DEST_DIR:"*) ;;
  *)
    echo
    echo "⚠ $DEST_DIR is not in your PATH."
    echo "  add this to your shell rc file:"
    echo "      export PATH=\"$DEST_DIR:\$PATH\""
    ;;
esac

echo
echo "try it:"
echo "  claude-peer register me"
echo "  claude-peer peers"
echo "  claude-peer help"
