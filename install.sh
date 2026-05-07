#!/usr/bin/env bash
# One-shot installer for cmdrvl/receipts skills.
#
# Curl-bash use case (LinkedIn link, README copy-paste):
#   curl -fsSL https://raw.githubusercontent.com/cmdrvl/receipts/main/install.sh | bash
#
# What it does (idempotent — safe to re-run):
#   1. Auto-detects which AI coding agent skill dirs exist on this machine
#      (~/.claude, ~/.codex, ~/.gemini, ~/.cursor, ~/.agents)
#   2. Clones (or pulls) the repo into a single bundle directory
#   3. Symlinks receipts-csv + receipts-flywheel into every detected
#      harness's skills/ directory — one bundle, many harnesses
#   4. Installs the cmdrvl spine tools via Homebrew
#   5. Prints next steps
#
# Environment overrides:
#   RECEIPTS_REPO_URL   override the repo URL (default: cmdrvl/receipts on GitHub)
#   RECEIPTS_REF        branch or tag to check out (default: main)
#   RECEIPTS_BUNDLE_DIR override bundle location entirely
#   SKIP_SPINE_INSTALL  set to 1 to skip the brew install pass

set -euo pipefail

REPO_URL="${RECEIPTS_REPO_URL:-https://github.com/cmdrvl/receipts.git}"
REF="${RECEIPTS_REF:-main}"

# Order matters: first existing harness root wins as the bundle home.
HARNESSES=(claude codex gemini cursor agents)

say()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m  ✓\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m  !\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

[[ -n "${HOME:-}" ]] || die "HOME is not set"
command -v git >/dev/null 2>&1 || die "git not found — install git first"

# 1. Detect harness skill dirs
say "detecting AI coding agent skill dirs"
DETECTED=()
for h in "${HARNESSES[@]}"; do
  if [[ -d "$HOME/.$h" ]]; then
    DETECTED+=("$h")
    ok "found ~/.$h"
  fi
done

if [[ ${#DETECTED[@]} -eq 0 ]]; then
  warn "no AI coding agent dirs found (~/.claude, ~/.codex, ~/.gemini, ~/.cursor, ~/.agents)"
  warn "creating ~/.claude/skills/ as the default home"
  mkdir -p "$HOME/.claude/skills"
  DETECTED=(claude)
fi

# 2. Pick bundle location: first detected harness, OR explicit override
if [[ -n "${RECEIPTS_BUNDLE_DIR:-}" ]]; then
  BUNDLE_DIR="$RECEIPTS_BUNDLE_DIR"
elif [[ -d "$HOME/.claude/skills/receipts-bundle/.git" ]]; then
  # back-compat: existing installs from before multi-harness support
  BUNDLE_DIR="$HOME/.claude/skills/receipts-bundle"
else
  BUNDLE_HARNESS="${DETECTED[0]}"
  BUNDLE_DIR="$HOME/.$BUNDLE_HARNESS/skills/receipts-bundle"
fi

# 3. Clone or update
mkdir -p "$(dirname "$BUNDLE_DIR")"
if [[ -d "$BUNDLE_DIR/.git" ]]; then
  say "updating $BUNDLE_DIR"
  git -C "$BUNDLE_DIR" fetch --quiet origin "$REF"
  git -C "$BUNDLE_DIR" checkout --quiet "$REF"
  git -C "$BUNDLE_DIR" pull --quiet --ff-only origin "$REF" || warn "could not fast-forward; leaving local commits in place"
  ok "repo at $(git -C "$BUNDLE_DIR" rev-parse --short HEAD)"
elif [[ -e "$BUNDLE_DIR" ]]; then
  die "$BUNDLE_DIR exists but is not a git repo. Move or remove it, then re-run."
else
  say "cloning $REPO_URL → $BUNDLE_DIR"
  git clone --quiet --branch "$REF" "$REPO_URL" "$BUNDLE_DIR"
  ok "cloned at $(git -C "$BUNDLE_DIR" rev-parse --short HEAD)"
fi

# 4. Symlink skills into every detected harness's skills/ dir
link_skill() {
  local name="$1" harness="$2"
  local target="$BUNDLE_DIR/skills/$name"
  local skills_dir="$HOME/.$harness/skills"
  local link="$skills_dir/$name"

  if [[ ! -d "$target" ]]; then
    warn "skill $name not found at $target — skipping"
    return
  fi

  mkdir -p "$skills_dir"

  if [[ -L "$link" ]]; then
    local current
    current="$(readlink "$link")"
    if [[ "$current" == "$target" ]]; then
      ok "[$harness] $name already linked"
      return
    fi
    warn "[$harness] $link points to $current — replacing"
    rm "$link"
  elif [[ -e "$link" ]]; then
    warn "[$harness] $link exists and is not a symlink — leaving in place. Move it aside if you want the bundled version."
    return
  fi

  ln -s "$target" "$link"
  ok "[$harness] linked $name"
}

say "linking skills into ${#DETECTED[@]} detected harness(es)"
for h in "${DETECTED[@]}"; do
  link_skill receipts-csv     "$h"
  link_skill receipts-flywheel "$h"
done

# 5. Install spine tools (unless skipped)
if [[ "${SKIP_SPINE_INSTALL:-0}" == "1" ]]; then
  say "skipping spine install (SKIP_SPINE_INSTALL=1)"
else
  say "installing cmdrvl spine tools via brew (idempotent)"
  if [[ -x "$BUNDLE_DIR/shared/scripts/install-spine.sh" ]]; then
    bash "$BUNDLE_DIR/shared/scripts/install-spine.sh"
  else
    warn "install-spine.sh not found or not executable — skipping. Run it manually:"
    warn "  bash $BUNDLE_DIR/shared/scripts/install-spine.sh"
  fi
fi

# 6. Next steps
cat <<EOF

$(printf '\033[1;32mok — receipts installed.\033[0m')

Bundle location:  $BUNDLE_DIR
Linked into:      $(printf '~/.%s ' "${DETECTED[@]}")

Try the bundled demo:

  bash $BUNDLE_DIR/skills/receipts-csv/scripts/run-receipt.sh \\
    $BUNDLE_DIR/skills/receipts-csv/assets/channel-spend/agency-report.csv \\
    $BUNDLE_DIR/skills/receipts-csv/assets/channel-spend/bank-statement.csv \\
    --key channel \\
    --out /tmp/my-first-receipt

Or, in any compatible session: /receipts-csv

Optional — keep CSV bytes out of the model context (privacy):

  bash $BUNDLE_DIR/shared/scripts/setup-veil.sh

That's an interactive guided installer for veil (the cmdrvl data-exfiltration
guard for AI coding agents). Skip it if you don't need the harness-level
guarantee — the skill works fine either way.

Repo: https://github.com/cmdrvl/receipts
EOF
