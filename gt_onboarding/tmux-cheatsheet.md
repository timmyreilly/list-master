# tmux Cheat Sheet for Gas Town

## Core Concepts

- **Session**: a named terminal workspace (e.g., `hq-mayor`, `lm-rictus`)
- **Window**: a tab inside a session
- **Pane**: a split inside a window
- **Detach**: leave a session running in the background

## Essential Commands (from your shell)

```bash
# List all sessions
tmux list-sessions

# Attach to a session (you're now "inside" it)
tmux attach -t hq-mayor

# Peek at a session without attaching (last 50 lines)
tmux capture-pane -t lm-rictus -p -S -50

# Kill a session
tmux kill-session -t hq-boot
```

## Inside a tmux Session

All tmux shortcuts start with **`Ctrl-b`** (the prefix key), then a second key:

| Keys | Action |
|------|--------|
| `Ctrl-b` then `d` | **Detach** — leave session running, go back to your shell |
| `Ctrl-b` then `[` | **Scroll mode** — arrow keys / PgUp to scroll, `q` to exit |
| `Ctrl-b` then `s` | **Session picker** — arrow through sessions, Enter to switch |
| `Ctrl-b` then `c` | Create a new window (tab) |
| `Ctrl-b` then `n` / `p` | Next / previous window |
| `Ctrl-b` then `0-9` | Jump to window by number |

## Gas Town Workflow

```bash
# See what's running
tmux list-sessions

# Watch the mayor work
tmux attach -t hq-mayor
# (Ctrl-b d to detach when done watching)

# Watch a polecat code
tmux attach -t lm-rictus
# (Ctrl-b d to detach)

# Quick peek without attaching
tmux capture-pane -t lm-slit -p -S -30

# Scroll back in a session you're attached to:
# Press Ctrl-b [    then PgUp/arrows    then q to exit scroll
```

## Key Gotcha

**Detach before switching sessions.** If you're attached to `hq-mayor` and want to see `lm-rictus`:

1. Press `Ctrl-b d` (detach from mayor)
2. Run `tmux attach -t lm-rictus`

Or switch directly with `Ctrl-b s` (session picker).

## Gas Town Session Names

| Session Pattern | What It Is |
|-----------------|-----------|
| `hq-mayor` | AI coordinator — plans work, creates beads, slings to polecats |
| `hq-boot` | Boot watchdog (monitors mayor health) |
| `hq-deacon` | Daemon manager (runs patrols) |
| `lm-<name>` | Polecat worker agents coding on specific beads |

## Sending Prompts to Sessions

```bash
# Write prompt to a file
cat > /tmp/prompt.txt << 'EOF'
Your prompt here
EOF

# Paste into a session and submit
tmux set-buffer -b myprompt "$(cat /tmp/prompt.txt)"
tmux paste-buffer -b myprompt -t hq-mayor
sleep 2
tmux send-keys -t hq-mayor Enter
```
