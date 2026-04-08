#!/usr/bin/env bash
# Gas Town setup & preflight check project.
#
# Usage:
#   ./setup.sh check     — Check prerequisites (read-only, safe to run anytime)
#   ./setup.sh install   — Install missing prerequisites
#   ./setup.sh init      — Create town workspace and add project rig
#   ./setup.sh all       — install + init in one shot
#
# Prerequisites:
#   - Git 2.25+, tmux 3.0+, sqlite3
#   - Go 1.25+ OR npm (for installing gt)
#   - Dolt 1.82.4+
#   - gt CLI (Gas Town)
#   - At least one agent CLI: claude, copilot (gh), codex, etc.

set -uo pipefail

# ── Configuration ───────────────────────────────────────────────────────
TOWN_ROOT="${GT_TOWN_ROOT:-$HOME/gt}"
PROJECT_REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RIG_NAME="list-master"
CREW_NAME="${USER:-$(whoami)}"

# Minimum versions
MIN_GIT="2.25"
MIN_TMUX="3.0"
MIN_DOLT="1.82.4"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

pass()  { printf "  ${GREEN}✓${NC} %s\n" "$1"; }
fail()  { printf "  ${RED}✗${NC} %s\n" "$1"; }
warn()  { printf "  ${YELLOW}⚠${NC} %s\n" "$1"; }
info()  { printf "  ${BLUE}→${NC} %s\n" "$1"; }
header(){ printf "\n${BOLD}%s${NC}\n" "$1"; }

# ── Version comparison ──────────────────────────────────────────────────
# Returns 0 if $1 >= $2 (semver-ish comparison)
version_gte() {
    # If "$2\n$1" is in sorted order, then $1 >= $2
    printf '%s\n%s\n' "$2" "$1" | sort -t. -k1,1n -k2,2n -k3,3n -C 2>/dev/null
}

# ── CHECK ───────────────────────────────────────────────────────────────
cmd_check() {
    header "Gas Town Preflight Check"
    local errors=0

    # Git
    if command -v git &>/dev/null; then
        local git_ver
        git_ver=$(git --version | grep -oP '\d+\.\d+\.\d+' | head -1)
        if version_gte "$git_ver" "$MIN_GIT"; then
            pass "git $git_ver (>= $MIN_GIT)"
        else
            fail "git $git_ver (need >= $MIN_GIT)"
            ((errors++))
        fi
    else
        fail "git not found"
        ((errors++))
    fi

    # tmux
    if command -v tmux &>/dev/null; then
        local tmux_ver
        tmux_ver=$(tmux -V | grep -oP '\d+\.\d+' | head -1)
        if version_gte "$tmux_ver" "$MIN_TMUX"; then
            pass "tmux $tmux_ver (>= $MIN_TMUX)"
        else
            fail "tmux $tmux_ver (need >= $MIN_TMUX)"
            ((errors++))
        fi
    else
        fail "tmux not found"
        ((errors++))
    fi

    # sqlite3
    if command -v sqlite3 &>/dev/null; then
        pass "sqlite3 $(sqlite3 --version 2>/dev/null | awk '{print $1}')"
    else
        fail "sqlite3 not found"
        ((errors++))
    fi

    # Go (optional — needed only if installing gt from source)
    if command -v go &>/dev/null; then
        local go_ver
        go_ver=$(go version | grep -oP '\d+\.\d+(\.\d+)?' | head -1)
        pass "go $go_ver"
    else
        warn "go not installed (optional — needed for gt source install)"
    fi

    # npm (alternative install path)
    if command -v npm &>/dev/null; then
        pass "npm $(npm --version 2>/dev/null)"
    else
        warn "npm not found (optional — alternative gt install method)"
    fi

    # Dolt
    if command -v dolt &>/dev/null; then
        local dolt_ver
        dolt_ver=$(dolt version | grep -oP '\d+\.\d+\.\d+' | head -1)
        if version_gte "$dolt_ver" "$MIN_DOLT"; then
            pass "dolt $dolt_ver (>= $MIN_DOLT)"
        else
            fail "dolt $dolt_ver (need >= $MIN_DOLT)"
            ((errors++))
        fi
    else
        fail "dolt not found"
        ((errors++))
    fi

    # gt (Gas Town CLI)
    if command -v gt &>/dev/null; then
        local gt_ver
        gt_ver=$(gt --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1 || echo "unknown")
        pass "gt $gt_ver"
    else
        fail "gt (Gas Town CLI) not found"
        ((errors++))
    fi

    # Agent runtimes (at least one needed)
    header "Agent Runtimes (need at least one)"
    local agents_found=0
    for agent in claude codex gh; do
        if command -v "$agent" &>/dev/null; then
            pass "$agent found"
            ((agents_found++))
        fi
    done
    if [[ $agents_found -eq 0 ]]; then
        warn "No agent CLI found (claude, codex, or gh with Copilot)"
        warn "You'll need at least one to use Gas Town"
    fi

    # Existing town check
    header "Workspace State"
    if [[ -f "$TOWN_ROOT/mayor/town.json" ]]; then
        pass "Town exists at $TOWN_ROOT"
        if [[ -d "$TOWN_ROOT/$RIG_NAME" ]]; then
            pass "Rig '$RIG_NAME' already added"
        else
            warn "Rig '$RIG_NAME' not yet added (run: ./setup.sh init)"
        fi
    else
        info "No town at $TOWN_ROOT (run: ./setup.sh init)"
    fi

    # Summary
    header "Summary"
    if [[ $errors -eq 0 ]]; then
        printf "  ${GREEN}${BOLD}All prerequisites met.${NC} Run ${BOLD}./setup.sh init${NC} to create the town.\n"
    else
        printf "  ${RED}${BOLD}$errors issue(s) found.${NC} Run ${BOLD}./setup.sh install${NC} to fix.\n"
    fi
    return $errors
}

# ── INSTALL ─────────────────────────────────────────────────────────────
cmd_install() {
    header "Installing Gas Town Prerequisites"

    # sqlite3
    if ! command -v sqlite3 &>/dev/null; then
        info "Installing sqlite3..."
        sudo apt-get update -qq && sudo apt-get install -y -qq sqlite3
        pass "sqlite3 installed"
    else
        pass "sqlite3 already installed"
    fi

    # Dolt
    if ! command -v dolt &>/dev/null; then
        info "Installing Dolt..."
        sudo bash -c 'curl -sL https://github.com/dolthub/dolt/releases/latest/download/install.sh | bash'
        pass "dolt installed"
    else
        pass "dolt already installed"
    fi

    # gt (Gas Town CLI)
    if ! command -v gt &>/dev/null; then
        if command -v npm &>/dev/null; then
            info "Installing gt via npm..."
            npm install -g @gastown/gt
            pass "gt installed via npm"
        elif command -v go &>/dev/null; then
            info "Installing gt via go install..."
            go install github.com/steveyegge/gastown/cmd/gt@latest
            pass "gt installed via go"
            info "Ensure \$HOME/go/bin is in your PATH"
        else
            fail "Cannot install gt: need npm or go. Install one of them first."
            info "  npm:  curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash - && sudo apt-get install -y nodejs"
            info "  go:   See https://go.dev/dl/"
            return 1
        fi
    else
        pass "gt already installed"
    fi

    header "Post-Install Check"
    cmd_check || true
}

# ── INIT ────────────────────────────────────────────────────────────────
cmd_init() {
    header "Initializing Gas Town"

    # Preflight
    for cmd in gt dolt git tmux; do
        if ! command -v "$cmd" &>/dev/null; then
            fail "$cmd is required but not found. Run ./setup.sh install first."
            return 1
        fi
    done

    # Create town
    if [[ -f "$TOWN_ROOT/mayor/town.json" ]]; then
        pass "Town already exists at $TOWN_ROOT"
    else
        info "Creating town at $TOWN_ROOT ..."
        gt install "$TOWN_ROOT" --git
        pass "Town created at $TOWN_ROOT"
    fi

    # Add rig
    if [[ -d "$TOWN_ROOT/$RIG_NAME" ]]; then
        pass "Rig '$RIG_NAME' already exists"
    else
        info "Adding rig '$RIG_NAME' from $PROJECT_REPO_ROOT ..."
        cd "$TOWN_ROOT"
        gt rig add "$RIG_NAME" "$PROJECT_REPO_ROOT"
        pass "Rig '$RIG_NAME' added"
    fi

    # Install directives
    local script_dir
    script_dir="$(cd "$(dirname "$0")" && pwd)"

    # Town-level mayor directive
    mkdir -p "$TOWN_ROOT/directives"
    if [[ ! -f "$TOWN_ROOT/directives/mayor.md" ]]; then
        cp "$script_dir/directives/mayor.md" "$TOWN_ROOT/directives/mayor.md"
        pass "Installed town directive: directives/mayor.md"
    else
        warn "Town directive directives/mayor.md already exists (skipped)"
    fi

    # Rig-level polecat directive
    mkdir -p "$TOWN_ROOT/$RIG_NAME/directives"
    if [[ ! -f "$TOWN_ROOT/$RIG_NAME/directives/polecat.md" ]]; then
        cp "$script_dir/directives/polecat.md" "$TOWN_ROOT/$RIG_NAME/directives/polecat.md"
        pass "Installed rig directive: $RIG_NAME/directives/polecat.md"
    else
        warn "Rig directive $RIG_NAME/directives/polecat.md already exists (skipped)"
    fi

    # Create crew workspace
    cd "$TOWN_ROOT"
    if [[ -d "$TOWN_ROOT/$RIG_NAME/crew/$CREW_NAME" ]]; then
        pass "Crew workspace '$CREW_NAME' already exists"
    else
        info "Creating crew workspace for '$CREW_NAME' ..."
        gt crew add "$CREW_NAME" --rig "$RIG_NAME"
        pass "Crew workspace created: $RIG_NAME/crew/$CREW_NAME"
    fi

    # Run doctor
    header "Workspace Health Check"
    cd "$TOWN_ROOT"
    gt doctor || warn "gt doctor reported issues (review above)"

    header "Done!"
    printf "\n"
    info "Town root:      $TOWN_ROOT"
    info "Project rig:    $TOWN_ROOT/$RIG_NAME"
    info "Crew workspace: $TOWN_ROOT/$RIG_NAME/crew/$CREW_NAME"
    printf "\n"
    info "Next steps:"
    info "  cd $TOWN_ROOT"
    info "  gt mayor attach"
    printf "\n"
    info "Then tell the Mayor about the specs in docs/"
}

# ── MAIN ────────────────────────────────────────────────────────────────
case "${1:-help}" in
    check)   cmd_check ;;
    install) cmd_install ;;
    init)    cmd_init ;;
    all)     cmd_install && cmd_init ;;
    *)
        echo "Usage: $0 {check|install|init|all}"
        echo ""
        echo "  check   — Verify prerequisites (read-only)"
        echo "  install — Install missing prerequisites (sqlite3, dolt, gt)"
        echo "  init    — Create town, add project rig, install directives"
        echo "  all     — install + init in one shot"
        exit 1
        ;;
esac
