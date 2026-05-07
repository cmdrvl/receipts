#!/usr/bin/env bash
# Install the cmdrvl spine tools required by receipts-* skills via the
# cmdrvl/tap Homebrew tap. Idempotent — skips already-installed tools.
#
# Coverage:
#   - macOS (arm64, x86_64): native bottles
#   - Linux (arm64, x86_64): native bottles
#   - Windows: use WSL2 (which is Linux); no native Windows bottles
#
# Usage:
#   install-spine.sh                    # install required tools for receipts-csv
#   install-spine.sh --include-optional # also install veil
#   install-spine.sh --all              # install every spine tool in the tap
#
# Note on formula names: the Homebrew tap uses prefixed formula names for
# tools that share a generic word (e.g. `cmdrvl-hash` not `hash`,
# `cmdrvl-benchmark` not `benchmark`) to avoid collisions with other taps.
# The installed binaries keep their natural names (`hashbytes`, `benchmark`).

set -euo pipefail

# Binary → formula map. Both must be tracked because they don't always match.
declare -a REQUIRED_BINS=(shape rvl pack)
declare -a REQUIRED_FORMULAS=(shape rvl pack)

declare -a OPTIONAL_BINS=(veil)
declare -a OPTIONAL_FORMULAS=(veil)

declare -a FULL_BINS=(vacuum hashbytes fingerprint shape profile rvl lock canon pack benchmark assess veil)
declare -a FULL_FORMULAS=(vacuum cmdrvl-hash fingerprint shape profile rvl lock canon pack cmdrvl-benchmark assess veil)

MODE="required"
case "${1:-}" in
  --include-optional) MODE="optional";;
  --all) MODE="all";;
  --help|-h)
    sed -n '1,30p' "$0"
    exit 0
    ;;
esac

case "$MODE" in
  required) BINS=("${REQUIRED_BINS[@]}");        FORMULAS=("${REQUIRED_FORMULAS[@]}");;
  optional) BINS=("${REQUIRED_BINS[@]}" "${OPTIONAL_BINS[@]}"); FORMULAS=("${REQUIRED_FORMULAS[@]}" "${OPTIONAL_FORMULAS[@]}");;
  all)      BINS=("${FULL_BINS[@]}");            FORMULAS=("${FULL_FORMULAS[@]}");;
esac

if ! command -v brew >/dev/null 2>&1; then
  cat >&2 <<'EOF'
error: Homebrew not found.

receipts-csv installs spine tools via brew. Install Homebrew first:

  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

On Linux this works the same way (Linuxbrew). On Windows, run inside WSL2 —
the cmdrvl tap ships Linux bottles but no native Windows binaries.

Or download spine binaries manually from the cmdrvl GitHub org:
each tool has its own repo with prebuilt binaries on its releases page.
EOF
  exit 1
fi

if ! brew tap 2>/dev/null | grep -q '^cmdrvl/tap$'; then
  echo "==> tapping cmdrvl/tap"
  brew tap cmdrvl/tap
fi

install_one() {
  local bin="$1" formula="$2"
  if command -v "$bin" >/dev/null 2>&1; then
    echo "==> $bin already installed ($("$bin" --version 2>/dev/null | head -1))"
    return 0
  fi
  echo "==> installing $bin (formula: cmdrvl/tap/$formula)"
  brew install "cmdrvl/tap/$formula"
}

for i in "${!BINS[@]}"; do
  install_one "${BINS[$i]}" "${FORMULAS[$i]}"
done

echo
echo "==> verifying installation"
missing=0
for bin in "${BINS[@]}"; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "  ✗ $bin MISSING"
    missing=$((missing + 1))
  else
    echo "  ✓ $bin $("$bin" --version 2>/dev/null | head -1 | awk '{print $NF}')"
  fi
done

if [[ $missing -gt 0 ]]; then
  echo "error: $missing tool(s) failed to install" >&2
  exit 1
fi

echo
echo "ok — spine ready."
