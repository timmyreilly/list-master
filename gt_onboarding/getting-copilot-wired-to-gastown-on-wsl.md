# Getting Copilot Wired to Gas Town on WSL

Step-by-step record of configuring Gas Town with GitHub Copilot as the agent
runtime on Ubuntu 24.04 (WSL). Completed April 3, 2026.

## System Baseline

| Component | Version | Status |
|-----------|---------|--------|
| OS | Ubuntu 24.04.3 LTS (Noble), x86_64, WSL | Pre-existing |
| Git | 2.43.0 | Pre-existing |
| tmux | 3.4 | Pre-existing |
| Node.js | v24.13.0 (via nvm) | Pre-existing |
| npm | 11.6.2 | Pre-existing |
| Python | 3.12.3 | Pre-existing |
| Podman/Docker | Both available | Pre-existing |
| `gh` CLI | Available | Pre-existing |
| `copilot` CLI | Installed by VS Code Copilot extension | Pre-existing |

## Step 1: Install sqlite3

Gas Town uses sqlite3 for convoy database queries.

```bash
sudo apt-get update -qq && sudo apt-get install -y -qq sqlite3
```

## Step 2: Install Dolt

Gas Town uses [Dolt](https://github.com/dolthub/dolt) (git-for-data) as the
storage backend for beads (the issue/work tracking system).

```bash
curl -sL https://github.com/dolthub/dolt/releases/latest/download/install.sh | sudo bash
```

Verify: `dolt version` → 1.85.0

## Step 3: Install Go 1.25+

Go is required to build `beads` (`bd` CLI) from source. Gas Town's npm package
(`@gastown/gt`) installs the `gt` binary, but `bd` must be compiled from Go source.

```bash
curl -sL https://go.dev/dl/go1.25.2.linux-amd64.tar.gz -o /tmp/go.tar.gz
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf /tmp/go.tar.gz
rm /tmp/go.tar.gz
```

Add to `~/.bashrc`:

```bash
export PATH="/usr/local/go/bin:$HOME/go/bin:$PATH"
```

Reload: `source ~/.bashrc`

Verify: `go version` → go1.25.2 linux/amd64

## Step 4: Install ICU development headers

The `beads` CLI uses `go-icu-regex` which requires ICU C headers for CGO compilation.
Without this, `go install` fails with `fatal error: unicode/uregex.h: No such file or directory`.

```bash
sudo apt-get install -y -qq libicu-dev pkg-config
```

## Step 5: Install beads (`bd` CLI)

```bash
GOTOOLCHAIN=auto go install github.com/steveyegge/beads/cmd/bd@latest
```

> **Note:** beads v1.0.0 requires go >= 1.25.8. The `GOTOOLCHAIN=auto` flag
> tells Go to automatically download the required toolchain version. This is
> why we install Go 1.25.2 first (as bootstrap) — it auto-upgrades to 1.25.8
> during the build.

Verify: `bd --version` → bd version 1.0.0 (dev)

Binary location: `~/go/bin/bd`

## Step 6: Install Gas Town (`gt` CLI)

```bash
npm install -g @gastown/gt
```

Verify: `gt --version` → gt version 0.12.0

Binary location: `~/.nvm/versions/node/v24.13.0/bin/gt`

## Step 7: Create the Gas Town workspace (Town)

```bash
gt install ~/gt --git
```

This creates:
- `~/gt/mayor/town.json` — Town configuration
- `~/gt/mayor/rigs.json` — Rig registry
- `~/gt/.beads/` — Town-level issue tracking (hq-* prefix)
- `~/gt/CLAUDE.md` + `AGENTS.md` — Agent identity anchors
- `~/gt/.git/` — Git repository for the town
- Dolt server started in background

Output includes:
```
🏭 Creating Gas Town HQ at /home/conductor/gt
   ✓ Created mayor/
   ✓ Created mayor/town.json
   ✓ Created mayor/rigs.json
   ✓ Initialized .beads/ (town-level beads with hq- prefix)
   ✓ Provisioned 42 formulas
   ...
✓ HQ created successfully!
```

## Step 8: Add the project as a rig

Since the repo is local-only (no git remote), use `--adopt --force`:

```bash
# Create rig directory structure with symlink to existing repo
mkdir -p ~/gt/list-master/mayor
ln -s /home/conductor/code/list-master ~/gt/list-master/mayor/rig

# Register the rig
cd ~/gt
gt rig add list-master --adopt --force
```

> **Why the symlink?** `gt rig add --adopt` expects the directory to already
> exist inside the town at `~/gt/<rig>/`. For repos with a remote URL, `gt rig add`
> clones directly. For local repos without a remote, create the structure manually
> and symlink.

Verify: `gt rig list` shows the rig:
```
⚫ list-master
   Witness: ○ stopped  Refinery: ○ stopped
   Polecats: 0  Crew: 0
```

## Step 9: Install directives

Directives are role-specific markdown files injected into agent context at
prime time.

```bash
# Town-level mayor directive (project context, convoy structure)
mkdir -p ~/gt/directives
cp gt_onboarding/directives/mayor.md ~/gt/directives/mayor.md

# Rig-level polecat directive (coding conventions, tech stack)
mkdir -p ~/gt/list-master/directives
cp gt_onboarding/directives/polecat.md ~/gt/list-master/directives/polecat.md
```

## Step 10: Set Copilot as the default agent

```bash
cd ~/gt
gt config default-agent copilot
```

The `copilot` preset uses `copilot --yolo` for autonomous mode. The Copilot CLI
binary was auto-installed by the VS Code Copilot extension at:
```
~/.vscode-server/data/User/globalStorage/github.copilot-chat/copilotCli/copilot
```

## Step 11: Run doctor and auto-fix

```bash
cd ~/gt
gt doctor --fix --no-start
```

This fixes:
- Missing agent beads
- Missing rig config.json
- Missing plugin directories
- Priming configuration
- Town-root CLAUDE.md sections
- Lifecycle patrol defaults

Final result: **80 passed, 0 failed, 4 warnings** (daemon not started, etc.)

## Step 12: Start the Mayor

```bash
cd ~/gt
gt mayor attach
```

Then tell the Mayor about the project and specs.

---

## Full Dependency Chain

```
gt (npm)
├── bd (go install, requires Go 1.25.8+)
│   ├── Go 1.25.2+ (bootstrap, auto-upgrades)
│   ├── libicu-dev (CGO, go-icu-regex)
│   └── pkg-config
├── dolt (binary release)
├── sqlite3 (apt)
├── git 2.25+
├── tmux 3.0+
└── copilot CLI (via VS Code extension)
```

## Troubleshooting

### `bd` install fails with `unicode/uregex.h: No such file or directory`

Missing ICU headers. Fix: `sudo apt-get install -y libicu-dev pkg-config`

### `gt install` fails with "beads dependency check failed"

Usually means `bd` isn't in PATH. Ensure `~/go/bin` is in your PATH:
```bash
export PATH="$HOME/go/bin:$PATH"
```

### `gt rig add` rejects local path

Gas Town only accepts remote URLs for `gt rig add <name> <url>`. For local
repos, use the symlink + `--adopt --force` approach described in Step 8.

### `gt mayor attach` fails

Requires tmux and one of the configured agent CLIs (copilot, claude, codex, etc.)
to be available in PATH. Check `gt config agent list` and verify the default
agent binary exists: `which copilot`

### Dolt server issues

Gas Town starts a Dolt server during `gt install`. Check status:
```bash
gt dolt status    # Is the server running?
gt dolt stop      # Stop it
gt dolt start     # Start it
```

### PATH not persisting

Add to `~/.bashrc`:
```bash
export PATH="/usr/local/go/bin:$HOME/go/bin:$PATH"
```
