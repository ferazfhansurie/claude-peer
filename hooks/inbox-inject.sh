#!/usr/bin/env bash
# inbox-inject.sh — Claude Code UserPromptSubmit hook for claude-peer.
#
# Reads unread peer messages for the current session and prints them to stdout
# so Claude Code injects them as additional context for the next turn. This is
# what makes peer messages auto-surface — the receiving session "wakes up" and
# reads its inbox without the user typing anything.
#
# Wire it up in ~/.claude/settings.json (install.sh does this for you):
#
#   {
#     "hooks": {
#       "UserPromptSubmit": [
#         { "hooks": [{
#             "type": "command",
#             "command": "/path/to/claude-peer/hooks/inbox-inject.sh",
#             "timeout": 5
#         }]}
#       ]
#     }
#   }

set -euo pipefail

HOME_DIR="${CLAUDE_PEER_HOME:-$HOME/.claude-peer}"
ME_FILE="$HOME_DIR/.me"

# Resolve current session — prefer tmux session name (auto-set by /aios-style
# launchers), then $CLAUDE_PEER_NAME, then ~/.claude-peer/.me.
if [[ -n "${TMUX:-}" ]] && command -v tmux >/dev/null 2>&1; then
  me=$(tmux display-message -p '#S' 2>/dev/null || true)
fi
if [[ -z "${me:-}" && -n "${CLAUDE_PEER_NAME:-}" ]]; then
  me="$CLAUDE_PEER_NAME"
fi
if [[ -z "${me:-}" && -f "$ME_FILE" ]]; then
  me=$(<"$ME_FILE")
fi
[[ -z "${me:-}" ]] && exit 0

inbox="$HOME_DIR/$me/inbox.jsonl"
marker="$HOME_DIR/$me/inbox.read"

[[ -s "$inbox" ]] || exit 0

prev=0
[[ -f "$marker" ]] && prev=$(<"$marker")
now=$(wc -c < "$inbox" 2>/dev/null | tr -d ' ')

(( now <= prev )) && exit 0

unread=$(tail -c "+$((prev+1))" "$inbox" 2>/dev/null || true)
printf '%s\n' "$now" > "$marker"

[[ -z "$unread" ]] && exit 0

printf '%s\n' "$unread" | python3 -c '
import json, sys
lines = []
for raw in sys.stdin:
    raw = raw.strip()
    if not raw:
        continue
    try:
        m = json.loads(raw)
        at = m.get("at", "?")
        sender = m.get("from", "?")
        body = m.get("body", "")
        lines.append("- [" + at + "] from " + sender + ": " + body)
    except Exception:
        continue
if lines:
    print("## claude-peer — new messages")
    print("\n".join(lines))
'
