#!/usr/bin/env bash
# One-shot installer for cmdrvl/receipts skills.
#
# Curl-bash use case (LinkedIn link, README copy-paste):
#   curl -fsSL https://raw.githubusercontent.com/cmdrvl/receipts/main/install.sh | bash
#
# What it does (idempotent — safe to re-run):
#   1. Clone (or pull) the repo into ~/.claude/skills/receipts-bundle/
#   2. Symlink receipts-csv + receipts-flywheel into ~/.claude/skills/
#   3. Install the cmdrvl spine tools via Homebrew (shape, rvl, pack, ...)
#   4. Print next steps
#
# Environment overrides:
#   RECEIPTS_REPO_URL  override the repo URL (default: cmdrvl/receipts on GitHub)
#   RECEIPTS_REF       branch or tag to check out (default: main)
#   SKIP_SPINE_INSTALL set to 1 to skip the brew install pass

set -euo pipefail

REPO_URL="${RECEIPTS_REPO_URL:-https://github.com/cmdrvl/receipts.git}"
REF="${RECEIPTS_REF:-main}"
SKILLS_DIR="$HOME/.claude/skills"
BUNDLE_DIR="$SKILLS_DIR/receipts-bundle"

say()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m  ✓\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m  !\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

if [[ -z "${HOME:-}" ]]; then
  die "HOME is not set"
fi

if ! command -v git >/dev/null 2>&1; then
  die "git not found — install git first (xcode-select --install on macOS, or your package manager)"
fi

mkdir -p "$SKILLS_DIR"

# 1. Clone or update
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

# 2. Symlink skills into ~/.claude/skills/
link_skill() {
  local name="$1"
  local target="$BUNDLE_DIR/skills/$name"
  local link="$SKILLS_DIR/$name"

  if [[ ! -d "$target" ]]; then
    warn "skill $name not found at $target — skipping"
    return
  fi

  if [[ -L "$link" ]]; then
    local current
    current="$(readlink "$link")"
    if [[ "$current" == "$target" ]]; then
      ok "$name already linked"
      return
    fi
    warn "$link points to $current — replacing"
    rm "$link"
  elif [[ -e "$link" ]]; then
    die "$link exists and is not a symlink. Move it aside, then re-run."
  fi

  ln -s "$target" "$link"
  ok "linked $name → $target"
}

say "linking skills into $SKILLS_DIR"
link_skill receipts-csv
link_skill receipts-flywheel

# 3. Install spine tools (unless skipped)
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

# 4. Next steps
cat <<EOF

$(printf '\033[1;32mok — receipts installed.\033[0m')

Try the bundled demo:

  bash $BUNDLE_DIR/skills/receipts-csv/scripts/run-receipt.sh \\
    $BUNDLE_DIR/skills/receipts-csv/assets/channel-spend/agency-report.csv \\
    $BUNDLE_DIR/skills/receipts-csv/assets/channel-spend/bank-statement.csv \\
    --key channel \\
    --out /tmp/my-first-receipt

Or, in any Claude Code session: /receipts-csv

For privacy when running inside an AI agent harness, install veil:

  brew install cmdrvl/tap/veil
  veil install
  veil config enable-pack data.tabular

Repo: https://github.com/cmdrvl/receipts
EOF
