# AGENTS.md — contributor guide for cmdrvl/receipts

This file is the rulebook for anyone (human or agent) modifying this repo. The user-facing pitch lives in `README.md`. This file is internal.

## Invariant: each skill is self-contained

Every skill under `skills/` must work standalone — when symlinked into a single harness's `~/.claude/skills/<skill>/`, when copied around, or when uploaded via `jsm push <skill-dir>` to jeffreys-skills.md.

Concretely:

- A skill's SKILL.md must reference scripts and assets via `./scripts/...` and `./assets/...` only. **No `../../shared/...`** — those paths break under symlink and standalone publishing.
- Every script a skill needs at runtime must live inside that skill's `scripts/` directory (not in a shared sibling).
- Every asset (CSV samples, fixtures) must live inside that skill's `assets/` directory.

If you find yourself adding a new top-level shared directory, stop and reconsider — symlink-resilience and jsm-pushability is the reason it doesn't exist.

## Canonical home: receipts-csv

`skills/receipts-csv/scripts/` is the **canonical** home of the spine bootstrapping and veil setup scripts. `skills/all-the-receipts/scripts/` mirrors it.

Files that are duplicated between the two skills:

| File | Purpose |
|---|---|
| `check-spine.sh` | Inventory which spine tools are installed |
| `install-spine.sh` | Bash installer for spine binaries (macOS / Linux via Homebrew) |
| `install-spine.ps1` | PowerShell installer for spine binaries (Windows native) |
| `setup-veil.sh` | Optional guided setup for the veil data-exfiltration guard |
| `run-receipt.sh` | The CSV pipeline runner (bash) |
| `run-receipt.ps1` | The CSV pipeline runner (PowerShell) |
| `assets/channel-spend/agency-report.csv` | Demo CSV |
| `assets/channel-spend/bank-statement.csv` | Demo CSV |

**When you change any of these files, update both skills in the same commit.** CI enforces this with a `diff -q` step in `.github/workflows/install-test.yml` — drift fails the build.

The mirroring direction is `receipts-csv → all-the-receipts`. If the two ever disagree, `receipts-csv` is the source of truth.

## Why mirror instead of symlink?

Git can store symlinks, but they don't survive every distribution path:

- macOS / Linux symlinks work in-repo but break under jsm `push <skill-dir>` because only the linked dir gets uploaded — the target lives outside it.
- Windows requires `core.symlinks=true` plus developer mode or admin to materialize git-stored symlinks. Many users have neither.
- Directory junctions (the Windows fallback we use at install-time via `mklink /J`) are made by the installer, not by git checkout.

Two physical copies + a CI drift check is the cheapest path that works everywhere.

## Files that reference the canonical path

These files all hard-code `skills/receipts-csv/scripts/...` as the install entry point. Update them together if the canonical home ever moves:

- `install.sh` — bash bundle installer
- `install.ps1` — PowerShell bundle installer
- `.github/workflows/install-test.yml` — CI smoke test
- `README.md` — manual install snippet, optional veil snippet, repo layout

## Bumping pinned tool versions

Spine tool versions are pinned in two places per skill (bash and PowerShell). When you bump:

1. Update `skills/receipts-csv/scripts/install-spine.sh` (the `REQUIRED` array)
2. Update `skills/receipts-csv/scripts/install-spine.ps1` (the `$Versions` hashtable)
3. Mirror both to `skills/all-the-receipts/scripts/`
4. CI catches drift but not stale-version coupling — verify locally that `shape --version` etc. still match expectations.

## Adding a new mode to all-the-receipts

The umbrella's contract is "feed two artifacts of compatible types, get a sealed pack." When adding a mode (PDF, filings, tape, etc.):

1. Implement the adapter inside `skills/all-the-receipts/scripts/` (e.g. `run-receipt-pdf.sh`).
2. Update `skills/all-the-receipts/SKILL.md` — add the mode to the *Modes* table, and add a routing rule to the *When invoked (workflow for the agent)* section.
3. Add a CI smoke test for the new mode if the artifacts can be checked in (small samples only).

`receipts-csv` does **not** grow new artifact types — it stays focused on CSV. New modes belong in `all-the-receipts`.

## Adding a new sibling skill

If a future skill (e.g. `receipts-pdf`) is genuinely self-contained and useful in isolation, it can live alongside `receipts-csv` and `all-the-receipts`. Same rules apply: vendored scripts only, no top-level `shared/`, must work under `jsm push`.

## Releasing to jeffreys-skills.md

We publish skills to jsm via `jsm push`. The release script `bin/release-jsm.sh` codifies the full contract — pre-flight checks plus the upload — so future releases don't relearn the gotchas.

### One-shot

```bash
./bin/release-jsm.sh all-the-receipts -m "csv mode polish + windows fix"
```

The script runs every check below in order and aborts on the first failure. No `--attest` to pass — it's already wired in.

### What gets validated before upload

1. **Skill directory exists** at `skills/<name>/`.
2. **Working tree is clean** — no uncommitted changes.
3. **On `main`, in sync with `origin/main`** — release only from pushed commits.
4. **Latest CI run on this commit succeeded** — uses `gh run list`. If `gh` isn't installed, the check is skipped with a warning.
5. **No exec bits** on `*.sh` / `*.ps1` files in the skill's `scripts/` directory. jsm's upload validator rejects executable files. We strip them in-repo and CI guards against drift.
6. **Drift check** between `receipts-csv` and `all-the-receipts` — the 6 mirrored scripts and 2 CSV samples must match. (Skipped if either skill is missing.)
7. **`jsm validate`** passes for the skill.

Then `jsm push --attest --lint-changelog -m "$MSG" skills/<name>/`.

### Required SKILL.md frontmatter for jsm uploads

jsm enforces these fields at upload (server-side, after local validation):

```yaml
---
name: <slug>
description: >-
  <what the skill does + when to invoke it>
license: MIT                    # or whatever license — required, free-form string
distribution: public            # one of: public | subscribers | forbidden
---
```

`name` and `description` alone pass `jsm validate`, but the upload server rejects without `license` and `distribution`. Our skills are MIT, freely shareable → `distribution: public`.

### The other things you set on jsm (not in frontmatter)

These live on jeffreys-skills.md itself, not in the SKILL.md, and are configured via the web UI when you publish:

- **Category** — we use `flywheel-tool` for `all-the-receipts`.
- **Compatibility tags** (max 5 per skill) — `ctx-data, ctx-cli, ctx-security, ctx-testing, ctx-devops` for `all-the-receipts`. Run `jsm tags` to see the full taxonomy.
- **Author notes** — short subscriber-facing context, what's working today vs growing.
- **Copyright** — `Copyright (c) 2026 cmdrvl`.

### When to bump the version

Every `jsm push` increments the version on the server. There's no manual version field in the frontmatter. Use the `-m` message to describe what changed; that becomes the changelog entry. `--lint-changelog` (already on by default in our script) catches malformed messages.

### What if we ever want a private/team-only release

Change `distribution: public` to `distribution: subscribers` (paying subscribers only) or `distribution: forbidden` (no redistribution; only for skills you intend to keep proprietary). The script doesn't enforce a particular value — set what you want in the SKILL.md frontmatter and run.

## What lives outside the skills

These three are the only things that legitimately live above the skills:

- `install.sh` / `install.ps1` — the curl|bash and iwr|iex installers that set up the bundle and link skills into harnesses. They reference `skills/receipts-csv/scripts/install-spine.sh` as the canonical install entry.
- `.github/workflows/install-test.yml` — CI.
- `bin/release-jsm.sh` — release tool for `jsm push` (see *Releasing to jeffreys-skills.md* above).

If you find a reason to add another top-level directory, document the reason here and explain how it preserves the symlink + jsm-push invariants.
