#!/usr/bin/env bash
# Guided veil setup for receipts-* skills.
#
# Veil is the cmdrvl data-exfiltration guard for AI coding agents — it
# hooks Claude Code's PreToolUse events and blocks direct reads of
# protected files into the model context. The receipts skills work
# without veil; this is purely for users who want a hard guarantee
# that no AI in their session reads the raw data.
#
# This script:
#   1. Installs the veil binary via brew (if missing)
#   2. Runs `veil install` to register the agent-harness hooks
#   3. Drops a starter ~/.config/veil/config.toml (if missing) that
#      protects common tabular paths and authorizes spine tools
#
# Idempotent — safe to re-run. Pass --yes for unattended execution.

set -euo pipefail

ASSUME_YES=false
if [[ "${1:-}" == "--yes" || "${1:-}" == "-y" ]]; then
  ASSUME_YES=true
fi

CONFIG_DIR="$HOME/.config/veil"
CONFIG_FILE="$CONFIG_DIR/config.toml"

say()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m  ✓\033[0m %s\n' "$*"; }
ask()  { printf '\033[1;33m  ?\033[0m %s ' "$*"; }
warn() { printf '\033[1;33m  !\033[0m %s\n' "$*" >&2; }

confirm() {
  local prompt="$1"
  if $ASSUME_YES; then
    return 0
  fi
  ask "$prompt [y/N]"
  read -r response
  [[ "$response" =~ ^[Yy] ]]
}

# Stage 1: brew install cmdrvl/tap/veil
say "checking veil binary"
if command -v veil >/dev/null 2>&1; then
  ok "veil installed: $(veil --version 2>/dev/null | head -1)"
else
  if ! command -v brew >/dev/null 2>&1; then
    warn "Homebrew not found. Install brew first, then re-run this script."
    warn "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    exit 1
  fi
  if confirm "veil is not installed. Install it now via brew?"; then
    if ! brew tap 2>/dev/null | grep -q '^cmdrvl/tap$'; then
      brew tap cmdrvl/tap
    fi
    brew install cmdrvl/tap/veil
    ok "veil installed: $(veil --version 2>/dev/null | head -1)"
  else
    warn "skipped — receipts will run without harness-level data protection."
    exit 0
  fi
fi

# Stage 2: veil install (registers Claude Code hooks)
say "checking veil harness hooks"
if grep -q "veil" "$HOME/.claude/settings.json" 2>/dev/null; then
  ok "veil hooks already registered in ~/.claude/settings.json"
else
  if confirm "Register veil's PreToolUse hooks in ~/.claude/settings.json? (one-time setup, gates Read/Grep/Bash on protected files)"; then
    veil install
    ok "harness hooks installed"
  else
    warn "skipped — veil binary present but hooks not registered. Run 'veil install' later when ready."
    exit 0
  fi
fi

# Stage 3: starter config.toml
say "checking veil config"
if [[ -f "$CONFIG_FILE" ]]; then
  ok "config exists: $CONFIG_FILE"
  echo "    edit it directly to add protected paths or authorized spine tools."
else
  if confirm "Drop a starter config at $CONFIG_FILE? (protects CSV/TSV/parquet by default; authorizes spine tools)"; then
    mkdir -p "$CONFIG_DIR"
    cat > "$CONFIG_FILE" <<'EOF'
# veil config — written by receipts setup-veil.sh
# Edit this file to control which paths are sensitive and which tools are
# authorized to read them as subprocesses.

[sensitivity]
# Glob patterns for files veil should treat as sensitive.
# Paths matching these are blocked from direct Read/Grep/Bash exposure.
protected = [
    "*.csv",
    "*.tsv",
    "*.parquet",
    "data/**",
    "exports/**",
]

[spine]
# Spine tools allowed to process sensitive files as subprocesses.
# These tools see the bytes; only their JSON output reaches the model.
authorized_tools = [
    "shape", "rvl", "vacuum", "hashbytes",
    "fingerprint", "profile", "canon", "lock", "pack",
]

[policy]
# What veil does on a hit. "deny" blocks; "warn" logs only.
default = "deny"
audit_log = true
EOF
    ok "wrote starter config to $CONFIG_FILE"
  else
    warn "skipped — no config written. veil will use built-in defaults until you create one."
  fi
fi

echo
ok "veil setup complete."
echo
echo "Inspect current config:    veil config"
echo "List built-in pack detectors: veil packs"
echo "Test a path:                veil scan <dir>"
echo "Project-level overrides:    drop a .veil.toml in your project root"
echo
echo "Receipts will continue to work whether veil is on or off — this is"
echo "purely for the harness-level guarantee that no AI in your session"
echo "reads the raw CSV bytes."
