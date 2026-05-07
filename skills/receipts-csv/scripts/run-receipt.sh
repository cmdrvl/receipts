#!/usr/bin/env bash
# Run the full receipts-csv pipeline against two CSVs and produce a
# sealed evidence pack. No LLM in the chain — every step is deterministic.
#
# Usage: run-receipt.sh <old.csv> <new.csv> [--key <column>] [--out <dir>] [--note <text>]
#
# Output: prints the pack_id and the path to the sealed pack on stdout.
# Exit codes:
#   0  pack created (NO_CHANGE or REAL_CHANGE; both are valid receipts)
#   2  refusal (shape incompatibility, etc.) — see refusal envelope on stdout

set -euo pipefail

OLD=""
NEW=""
KEY=""
OUT=""
NOTE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --key) KEY="$2"; shift 2;;
    --out) OUT="$2"; shift 2;;
    --note) NOTE="$2"; shift 2;;
    --help|-h)
      echo "Usage: $0 <old.csv> <new.csv> [--key <column>] [--out <dir>] [--note <text>]"
      exit 0
      ;;
    -*)
      echo "error: unknown flag: $1" >&2
      exit 2
      ;;
    *)
      if [[ -z "$OLD" ]]; then OLD="$1"
      elif [[ -z "$NEW" ]]; then NEW="$1"
      else echo "error: too many positional args" >&2; exit 2
      fi
      shift
      ;;
  esac
done

if [[ -z "$OLD" || -z "$NEW" ]]; then
  echo "error: need <old.csv> <new.csv>" >&2
  exit 2
fi

if [[ ! -f "$OLD" ]]; then echo "error: not found: $OLD" >&2; exit 2; fi
if [[ ! -f "$NEW" ]]; then echo "error: not found: $NEW" >&2; exit 2; fi

WORK="$(mktemp -d -t receipts-XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

KEY_FLAG=()
if [[ -n "$KEY" ]]; then KEY_FLAG=(--key "$KEY"); fi

NOTE_FLAG=()
if [[ -n "$NOTE" ]]; then NOTE_FLAG=(--note "$NOTE"); fi

OUT_FLAG=()
if [[ -n "$OUT" ]]; then
  mkdir -p "$OUT"
  OUT_FLAG=(--output "$OUT")
fi

echo "==> shape"
if ! shape "$OLD" "$NEW" "${KEY_FLAG[@]+"${KEY_FLAG[@]}"}" --json --no-witness > "$WORK/shape.report.json"; then
  echo "shape REFUSAL — structural incompatibility:" >&2
  cat "$WORK/shape.report.json" >&2
  exit 2
fi
python3 -c "import json,sys; d=json.load(open('$WORK/shape.report.json')); print(f\"  shape: {d['outcome']}\")"

echo "==> rvl"
RVL_EXIT=0
rvl "$OLD" "$NEW" "${KEY_FLAG[@]+"${KEY_FLAG[@]}"}" --json --no-witness > "$WORK/rvl.report.json" || RVL_EXIT=$?
if [[ $RVL_EXIT -eq 2 ]]; then
  echo "rvl REFUSAL:" >&2
  cat "$WORK/rvl.report.json" >&2
  exit 2
fi
python3 - "$WORK/rvl.report.json" <<'PYEOF'
import json, sys
d = json.load(open(sys.argv[1]))
outcome = d["outcome"]
counts = d.get("counts", {})
metrics = d.get("metrics", {})
print(f"  rvl:   {outcome}")
if outcome == "REAL_CHANGE":
    print(f"  rvl:   {counts.get('numeric_cells_changed', '?')} cells changed across {counts.get('rows_aligned', '?')} aligned rows")
    print(f"  rvl:   total numeric movement: {metrics.get('total_change', '?')}")
PYEOF

echo "==> pack seal"
pack seal "$WORK/shape.report.json" "$WORK/rvl.report.json" \
  "${OUT_FLAG[@]+"${OUT_FLAG[@]}"}" "${NOTE_FLAG[@]+"${NOTE_FLAG[@]}"}" \
  --no-witness > "$WORK/pack.out" 2>&1 || {
    echo "pack REFUSAL:" >&2
    cat "$WORK/pack.out" >&2
    exit 2
  }

# Parse pack_id from "PACK_CREATED <pack_id>" line
PACK_ID=$(awk '/^PACK_CREATED/ {print $2}' "$WORK/pack.out")
PACK_DIR=$(awk 'NR==2 {print $1}' "$WORK/pack.out")

echo
echo "  pack_id: $PACK_ID"
echo "  pack:    $PACK_DIR"
echo

echo "==> pack verify"
if pack verify "$PACK_DIR" --no-witness > "$WORK/verify.out" 2>&1; then
  echo "  verify: OK"
else
  echo "  verify: FAILED" >&2
  cat "$WORK/verify.out" >&2
  exit 1
fi
