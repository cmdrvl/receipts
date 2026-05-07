#!/usr/bin/env bash
# Install missing spine tools via cmdrvl/tap. Idempotent.
# Skips already-installed tools. Verifies versions after install.
#
# Usage: install-spine.sh [--include-optional]
#   --include-optional  also install veil (data exfiltration guard)

set -euo pipefail

INCLUDE_OPTIONAL=false
if [[ "${1:-}" == "--include-optional" ]]; then
  INCLUDE_OPTIONAL=true
fi

REQUIRED=(vacuum hashbytes fingerprint shape profile rvl lock canon pack)
OPTIONAL=(veil)

if ! command -v brew >/dev/null 2>&1; then
  cat >&2 <<'EOF'
error: Homebrew not found.

receipts-csv installs spine tools via brew. Install Homebrew first:

  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

Or download spine binaries manually from https://github.com/cmdrvl
(each tool has its own repo with prebuilt binaries on releases page).
EOF
  exit 1
fi

if ! brew tap 2>/dev/null | grep -q '^cmdrvl/tap$'; then
  echo "==> tapping cmdrvl/tap"
  brew tap cmdrvl/tap
fi

install_one() {
  local tool="$1"
  if command -v "$tool" >/dev/null 2>&1; then
    echo "==> $tool already installed ($("$tool" --version 2>/dev/null | head -1))"
    return 0
  fi
  echo "==> installing $tool"
  brew install "cmdrvl/tap/$tool"
}

for t in "${REQUIRED[@]}"; do
  install_one "$t"
done

if $INCLUDE_OPTIONAL; then
  for t in "${OPTIONAL[@]}"; do
    install_one "$t"
  done
fi

echo
echo "==> verifying installation"
missing=0
for t in "${REQUIRED[@]}"; do
  if ! command -v "$t" >/dev/null 2>&1; then
    echo "  ✗ $t MISSING"
    missing=$((missing + 1))
  else
    echo "  ✓ $t $("$t" --version 2>/dev/null | head -1 | awk '{print $NF}')"
  fi
done

if [[ $missing -gt 0 ]]; then
  echo "error: $missing required tool(s) failed to install" >&2
  exit 1
fi

echo
echo "ok — spine ready."
