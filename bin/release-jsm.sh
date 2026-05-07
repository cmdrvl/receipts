#!/usr/bin/env bash
# Release a skill to jeffreys-skills.md.
#
# Usage:
#   bin/release-jsm.sh <skill-name> -m "<changelog message>"
#   bin/release-jsm.sh all-the-receipts -m "csv mode polish + windows fix"
#
# Pre-flight checks (all enforced — fail fast, exit 1):
#   1. Skill directory exists at skills/<skill-name>/
#   2. Working tree is clean (no uncommitted changes)
#   3. Current branch is main and pushed to origin
#   4. The latest CI run on origin/main succeeded
#   5. No script files in skills/<skill-name>/scripts/ have the exec bit
#      (jsm rejects executable files at upload — see guidelines)
#   6. If skills/all-the-receipts/scripts/ exists alongside
#      skills/receipts-csv/scripts/, mirrored files match (drift check)
#   7. `jsm validate` passes for the skill
#
# Release:
#   8. `jsm push --attest -m "$message"` — uploads new version
#
# Required frontmatter in the skill's SKILL.md (jsm enforces these):
#   - name
#   - description
#   - license
#   - distribution     (one of: public | subscribers | forbidden)
#
# Re-run safe — if pre-flight fails, no upload happens.

set -euo pipefail

SKILL=""
MSG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -m|--message) MSG="$2"; shift 2;;
    -h|--help)
      sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    -*)
      echo "error: unknown flag: $1" >&2
      exit 2
      ;;
    *)
      if [[ -z "$SKILL" ]]; then SKILL="$1"
      else echo "error: too many positional args" >&2; exit 2
      fi
      shift
      ;;
  esac
done

if [[ -z "$SKILL" ]]; then
  echo "usage: $0 <skill-name> -m \"<changelog message>\"" >&2
  exit 2
fi
if [[ -z "$MSG" ]]; then
  echo "error: -m / --message is required (changelog message for this version)" >&2
  exit 2
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

SKILL_DIR="skills/$SKILL"
[[ -d "$SKILL_DIR" ]] || { echo "error: $SKILL_DIR does not exist" >&2; exit 1; }

say()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m  ✓\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31m  ✗\033[0m %s\n' "$*" >&2; exit 1; }

# 1. Working tree clean
say "checking working tree is clean"
if [[ -n "$(git status --porcelain)" ]]; then
  git status --short
  fail "uncommitted changes — commit or stash before releasing"
fi
ok "clean"

# 2. On main, up-to-date with origin
say "checking branch is main and up-to-date with origin"
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
[[ "$BRANCH" == "main" ]] || fail "must release from main (currently on $BRANCH)"
git fetch --quiet origin main
LOCAL="$(git rev-parse HEAD)"
REMOTE="$(git rev-parse origin/main)"
[[ "$LOCAL" == "$REMOTE" ]] || fail "main is not in sync with origin/main (push your commits first)"
ok "main @ $(git rev-parse --short HEAD) matches origin/main"

# 3. Latest CI run on this commit succeeded
say "checking latest CI run on origin/main"
if command -v gh >/dev/null 2>&1; then
  RUN_STATUS="$(gh run list --branch main --workflow install-test.yml --limit 1 --json status,conclusion,headSha --jq '.[0]')"
  RUN_SHA="$(echo "$RUN_STATUS" | python3 -c "import json,sys;print(json.load(sys.stdin)['headSha'])")"
  RUN_CONC="$(echo "$RUN_STATUS" | python3 -c "import json,sys;print(json.load(sys.stdin)['conclusion'])")"
  RUN_STATE="$(echo "$RUN_STATUS" | python3 -c "import json,sys;print(json.load(sys.stdin)['status'])")"
  if [[ "$RUN_SHA" != "$LOCAL" ]]; then
    fail "latest CI run is for $RUN_SHA, not $LOCAL — wait for CI to start, or push if needed"
  fi
  if [[ "$RUN_STATE" != "completed" ]]; then
    fail "CI is still $RUN_STATE — wait for it to finish"
  fi
  if [[ "$RUN_CONC" != "success" ]]; then
    fail "CI conclusion is $RUN_CONC — fix before releasing"
  fi
  ok "CI green on $LOCAL"
else
  printf '  ! gh not installed — skipping CI check\n' >&2
fi

# 4. No exec bit on .sh / .ps1 files in the skill (jsm rejects executables)
say "checking no script in $SKILL_DIR/scripts has the exec bit"
if [[ -d "$SKILL_DIR/scripts" ]]; then
  EXEC_FILES=()
  for f in "$SKILL_DIR/scripts/"*.sh "$SKILL_DIR/scripts/"*.ps1; do
    [[ -e "$f" ]] || continue
    [[ -x "$f" ]] && EXEC_FILES+=("$f")
  done
  if [[ ${#EXEC_FILES[@]} -gt 0 ]]; then
    printf '  exec bit set on:\n' >&2
    printf '    %s\n' "${EXEC_FILES[@]}" >&2
    fail "strip exec bits with: chmod -x ${EXEC_FILES[*]}"
  fi
  ok "no exec bits"
else
  printf '  · no scripts/ dir — skipping\n'
fi

# 5. Drift check between receipts-csv and all-the-receipts (when both present)
if [[ -d skills/receipts-csv/scripts && -d skills/all-the-receipts/scripts ]]; then
  say "drift check: receipts-csv ↔ all-the-receipts"
  for f in check-spine.sh install-spine.sh install-spine.ps1 setup-veil.sh run-receipt.sh run-receipt.ps1; do
    [[ -e "skills/receipts-csv/scripts/$f" && -e "skills/all-the-receipts/scripts/$f" ]] || continue
    diff -q "skills/receipts-csv/scripts/$f" "skills/all-the-receipts/scripts/$f" >/dev/null \
      || fail "$f drifted between the two skills — sync before releasing (receipts-csv is canonical)"
  done
  for f in agency-report.csv bank-statement.csv; do
    src="skills/receipts-csv/assets/channel-spend/$f"
    dst="skills/all-the-receipts/assets/channel-spend/$f"
    [[ -e "$src" && -e "$dst" ]] || continue
    diff -q "$src" "$dst" >/dev/null || fail "asset $f drifted between the two skills"
  done
  ok "no drift"
fi

# 6. jsm validate
say "running jsm validate"
command -v jsm >/dev/null 2>&1 || fail "jsm not on PATH — install the jsm CLI"
jsm validate "$SKILL_DIR" >/dev/null
ok "jsm validate passed"

# 7. Push
say "running jsm push --attest -m \"$MSG\""
echo
jsm push --attest --lint-changelog -m "$MSG" "$SKILL_DIR"
echo
ok "released $SKILL"
