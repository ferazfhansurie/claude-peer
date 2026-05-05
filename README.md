# claude-peer

agent-to-agent comms primitive. ~150 lines of bash. no daemon, no port, no cloud.

drop it into any agent runtime — claude code, cursor, codex CLI, continue, your own bash script — and two agents can talk to each other peer-to-peer.

## install

```bash
curl -fsSL https://raw.githubusercontent.com/ferazfhansurie/claude-peer/main/install.sh | bash
```

requires `bash`, `python3` (for safe JSON escaping), `tail`. ships on every macOS and most linux out of the box.

## the entire surface

```
claude-peer register <name>          declare this process as <name>
claude-peer send <peer> "<message>"  append to peer's inbox
claude-peer inbox                    read your inbox
claude-peer listen                   tail your inbox to stdout
claude-peer peers                    list registered peers + last-seen
claude-peer whoami                   echo your registered name
claude-peer unregister               remove your registration
```

five verbs do real work. that's it.

## auto-react in Claude Code

claude is reactive — a session only "wakes up" when you type. so by default, peer messages sit in `inbox.jsonl` until the recipient runs `claude-peer inbox`.

`install.sh` fixes that by wiring a `UserPromptSubmit` hook into `~/.claude/settings.json`. the hook reads unread peer messages and prints them to stdout — claude code injects that as additional context for the next turn. so the moment the recipient submits **any** prompt, the peer messages land in the model's context and it reacts.

want the recipient to react *without* the user typing anything? if both sides are inside tmux, `send` also fires `Enter` on the recipient's pane via `tmux send-keys`. the hook fires, the messages surface, the recipient acts in real time. set `CLAUDE_PEER_NO_POKE=1` to disable.

```
─────────────────────────────────────────────
  session: alice           session: bob
  ────────────             ────────────
  $ claude-peer send bob "FCA-91 broken — see /tmp/log"
  → bob: FCA-91 broken …

                            ## claude-peer — new messages
                            - [..] from alice: FCA-91 broken — see /tmp/log
                            → reading /tmp/log …
─────────────────────────────────────────────
```

## two-shell example

shell A:

```bash
claude-peer register alice
claude-peer send bob "branch off main, run the migration"
```

shell B:

```bash
claude-peer register bob
claude-peer listen
# {"id":"...","from":"alice","to":"bob","at":"...","body":"branch off main, run the migration"}
```

`listen` is `tail -F` on a file. wire it into your runtime however you like — pipe through `jq`, fire a hook, inject into a prompt.

## how it works

state lives at `$CLAUDE_PEER_HOME` (default `~/.claude-peer/`):

```
~/.claude-peer/
  alice/
    meta.json       name, started_at, pwd
    heartbeat       mtime touched on every command
    inbox.jsonl     append-only — what others sent us
    outbox.jsonl   append-only — what we sent
  bob/
    ...
```

- **transport: filesystem.** atomic JSONL appends are POSIX-guaranteed under PIPE_BUF (4096 bytes on macOS). no locks needed.
- **presence: heartbeat mtime.** every command touches `heartbeat`. `peers` reports last-seen.
- **wire format: one JSON object per line.** `id`, `from`, `to`, `at`, `body`. forwards-compat by ignoring unknown keys.

## why filesystem first

- works across any process, any shell, any agent runtime
- works across remote sessions over NFS / sshfs
- introspectable with `cat`, `tail -F`, `jq`
- no daemon to crash, no port to collide, no firewall to fight
- no cloud, no telemetry, no phone-home

future adapters (unix socket, ssh, websocket) plug in behind the same surface. transport is a config knob, not a different command.

## naming yourself per-shell

`register` writes your name to `~/.claude-peer/.me`, so subsequent commands in that shell pick it up. override for one command:

```bash
CLAUDE_PEER_NAME=alice claude-peer send bob "from alice without registering"
```

useful in scripts.

## what it doesn't do

- no auth — filesystem permissions are the auth (until adapters land)
- no notification UI — distros add that
- no cross-machine relay yet — the filesystem transport is local-only; ssh / unix-socket adapters are on the roadmap
- no opinion on which agents talk — claude code is the first-class target via the hook, but the CLI works in cursor, codex, continue, your own bash script, anything that can `exec`

this is a primitive, not a platform.

## why

i was running three claude code sessions in parallel — one per repo, one per branch — and they needed to talk to each other. claude desktop can't do that. subagents collapse to a summary string. a cloud queue is overkill for two processes on the same laptop.

so i wrote this. the whole tool is in [`bin/claude-peer`](bin/claude-peer). go read it.

day 7 of [30 days, 30 tools](https://github.com/ferazfhansurie).

## license

MIT. take it, fork it, embed it, ship it.

— firaz · [@firazfhansurie](https://www.linkedin.com/in/firazfhansurie/)
