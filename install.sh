#!/usr/bin/env bash
# claude-peer installer
#
#   1. drops the CLI into ~/.local/bin
#   2. (optional) wires the UserPromptSubmit hook into ~/.claude/settings.json
#      so peer messages auto-surface in Claude Code without you running
#      `claude-peer inbox` manually.
#
# Re-running is safe — both steps are idempotent.

set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/ferazfhansurie/claude-peer/main"
DEST_DIR="${CLAUDE_PEER_INSTALL_DIR:-$HOME/.local/bin}"
DEST="$DEST_DIR/claude-peer"
HOOK_DIR="${CLAUDE_PEER_HOOK_DIR:-$HOME/.claude-peer/_hooks}"
HOOK="$HOOK_DIR/inbox-inject.sh"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"

mkdir -p "$DEST_DIR" "$HOOK_DIR"

# 1. CLI -----------------------------------------------------------------------
echo "→ fetching claude-peer CLI..."
curl -fsSL "$REPO_RAW/bin/claude-peer" -o "$DEST"
chmod +x "$DEST"
echo "✓ installed: $DEST"

# 2. Hook (only if Claude Code is around) --------------------------------------
if [[ -d "$HOME/.claude" ]] || command -v claude >/dev/null 2>&1; then
  echo "→ fetching UserPromptSubmit hook..."
  curl -fsSL "$REPO_RAW/hooks/inbox-inject.sh" -o "$HOOK"
  chmod +x "$HOOK"
  echo "✓ hook installed: $HOOK"

  # Wire the hook into ~/.claude/settings.json (idempotent).
  mkdir -p "$HOME/.claude"
  if [[ ! -f "$CLAUDE_SETTINGS" ]]; then
    printf '{}\n' > "$CLAUDE_SETTINGS"
  fi

  python3 - "$CLAUDE_SETTINGS" "$HOOK" <<'PY'
import json, sys
settings_path, hook_cmd = sys.argv[1], sys.argv[2]
try:
    with open(settings_path) as f:
        d = json.load(f)
except Exception:
    d = {}

d.setdefault("hooks", {})
hooks = d["hooks"].setdefault("UserPromptSubmit", [])

already = any(
    any(h.get("command", "") == hook_cmd for h in entry.get("hooks", []))
    for entry in hooks
)

if already:
    print("✓ UserPromptSubmit hook already wired in", settings_path)
else:
    hooks.append({
        "hooks": [{
            "type":    "command",
            "command": hook_cmd,
            "timeout": 5,
        }],
    })
    with open(settings_path, "w") as f:
        json.dump(d, f, indent=2)
    print("✓ wired UserPromptSubmit hook → ~/.claude/settings.json")
PY
fi

# 3. PATH check ----------------------------------------------------------------
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
