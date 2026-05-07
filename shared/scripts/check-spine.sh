#!/usr/bin/env bash
# Check which spine tools are installed and emit a JSON inventory.
# Used by receipts-* skills to know whether to prompt for install.
#
# Spine tools: vacuum, hashbytes, fingerprint, shape, profile, rvl,
# lock, canon, pack. Veil (data exfiltration guard) is a spine tool too.
#
# Output: JSON to stdout listing each tool and its status.
# Exit 0 always — the skill decides what to do with missing tools.

set -euo pipefail

# Required for the receipts-csv pipeline (must match install-spine.sh).
REQUIRED=(shape rvl pack)

# Available in the spine but not strictly needed for receipts-csv. veil is
# the privacy guard; the rest are exercised by receipts-flywheel modes
# (PDF, filings, tape) as those land.
OPTIONAL=(veil vacuum hashbytes fingerprint profile lock canon)

emit_tool() {
  local tool="$1" required="$2"
  if command -v "$tool" >/dev/null 2>&1; then
    local v
    v=$("$tool" --version 2>/dev/null | head -1 | awk '{print $NF}')
    printf '    {"name": "%s", "installed": true, "version": "%s", "required": %s}' \
      "$tool" "$v" "$required"
  else
    printf '    {"name": "%s", "installed": false, "version": null, "required": %s}' \
      "$tool" "$required"
  fi
}

printf '{\n  "tools": [\n'

first=true
for t in "${REQUIRED[@]}"; do
  $first || printf ',\n'
  emit_tool "$t" true
  first=false
done
for t in "${OPTIONAL[@]}"; do
  printf ',\n'
  emit_tool "$t" false
done

printf '\n  ],\n'

# Has the cmdrvl tap?
if brew tap 2>/dev/null | grep -q '^cmdrvl/tap$'; then
  printf '  "tap_added": true,\n'
else
  printf '  "tap_added": false,\n'
fi

# Brew available at all?
if command -v brew >/dev/null 2>&1; then
  printf '  "brew_available": true\n'
else
  printf '  "brew_available": false\n'
fi

printf '}\n'
