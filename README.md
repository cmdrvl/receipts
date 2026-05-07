# receipts

> **Got two artifacts? Get a sealed receipt of what changed.**
>
> Deterministic, content-addressed evidence packs. No LLM in the chain. Verifiable offline.

This repo hosts two free, MIT-licensed skills that wrap the [cmdrvl spine](https://github.com/cmdrvl) into one-invocation receipt generators for AI coding agents and operators.

## The skills

| Skill | Status | Use when |
|---|---|---|
| **[receipts-csv](skills/receipts-csv/)** | shipping | You have two CSVs and want a hash-verified receipt of what changed. Focused, single-purpose. |
| **[all-the-receipts](skills/all-the-receipts/)** | shipping (CSV mode), expanding | You want one skill that mines receipts from any pair of artifacts. CSV mode runs the same pipeline as `receipts-csv` today; PDF / SEC filings / loan tapes / position files land as flywheel-paired modes ship. |

Both run on the same spine: `shape` (structural gate) → `rvl` (numeric verdict) → `pack seal` (content-addressed evidence pack). Every artifact has a SHA-256 identity. Every refusal is structured. `pack verify` revalidates the chain offline — no network, no catalog, no trust in the producer.

## Install

### macOS / Linux (bash)

```bash
curl -fsSL https://raw.githubusercontent.com/cmdrvl/receipts/main/install.sh | bash
```

Auto-detects every AI coding agent skill dir on your machine (`~/.claude`, `~/.codex`, `~/.gemini`, `~/.cursor`, `~/.agents`), clones the repo into a single bundle, symlinks both skills (`receipts-csv` and `all-the-receipts`) into each detected harness's `skills/` dir, and installs the cmdrvl spine via Homebrew. Idempotent — safe to re-run for updates.

Prereq: Homebrew. `install.sh` checks for `brew` and prints clear install instructions if it's missing.

If you prefer not to pipe `curl` to `bash`, [read `install.sh`](install.sh) first and run it locally.

### Windows (PowerShell, no bash required)

```powershell
iwr -useb https://raw.githubusercontent.com/cmdrvl/receipts/main/install.ps1 | iex
```

Native PowerShell installer — no Git Bash, no WSL2, no Cygwin needed. Downloads pinned spine binaries (`shape.exe`, `rvl.exe`, `pack.exe`) from each tool's GitHub releases into `%USERPROFILE%\.cmdrvl\bin`, adds it to your user PATH, clones the repo, and creates directory junctions (no admin / dev mode required) into each detected harness's `skills/` dir.

Run the bundled demo with `run-receipt.ps1`:

```powershell
& "$env:USERPROFILE\.claude\skills\receipts-bundle\skills\receipts-csv\scripts\run-receipt.ps1" `
  "$env:USERPROFILE\.claude\skills\receipts-bundle\skills\receipts-csv\assets\channel-spend\agency-report.csv" `
  "$env:USERPROFILE\.claude\skills\receipts-bundle\skills\receipts-csv\assets\channel-spend\bank-statement.csv" `
  -Key channel -Out (Join-Path $env:TEMP "my-first-receipt")
```

Prereq: [Git for Windows](https://git-scm.com/download/win) (provides `git`).

### Platform coverage

| Platform | Spine binaries | Install path |
|---|---|---|
| macOS arm64 / x86_64 | native bottles | `install.sh` (brew) |
| Linux arm64 / x86_64 | native bottles | `install.sh` (Linuxbrew) |
| Windows x86_64       | native `.exe`  | `install.ps1` (PowerShell) |
| Windows ARM64        | x86_64 via emulation | `install.ps1` |

### Manual

```bash
git clone https://github.com/cmdrvl/receipts.git ~/.claude/skills/receipts-bundle
ln -s ~/.claude/skills/receipts-bundle/skills/receipts-csv      ~/.claude/skills/receipts-csv
ln -s ~/.claude/skills/receipts-bundle/skills/all-the-receipts  ~/.claude/skills/all-the-receipts
~/.claude/skills/receipts-bundle/skills/receipts-csv/scripts/install-spine.sh
```

### Optional: keep your CSV bytes out of the model context

The skills work fine without this. It's a privacy enhancement for people who want a hard guarantee that no AI model in their session reads the raw data.

If you want it, an interactive setup script walks you through three stages — install the `veil` binary, register the agent-harness hooks, drop a conservative starter config — asking for confirmation before each:

```bash
~/.claude/skills/receipts-bundle/skills/receipts-csv/scripts/setup-veil.sh
```

Pass `--yes` to skip prompts.

## Quick start

After install:

```bash
# In any Claude Code session
/receipts-csv

# Or run the bundled demo directly
~/.claude/skills/receipts-bundle/skills/receipts-csv/scripts/run-receipt.sh \
  ~/.claude/skills/receipts-bundle/skills/receipts-csv/assets/channel-spend/agency-report.csv \
  ~/.claude/skills/receipts-bundle/skills/receipts-csv/assets/channel-spend/bank-statement.csv \
  --key channel \
  --out /tmp/channel-spend-receipt
```

In about 30 seconds you'll see:

```
==> shape
  shape: COMPATIBLE
==> rvl
  rvl:   REAL_CHANGE
  rvl:   6 cells changed across 5 aligned rows
  rvl:   total numeric movement: 3029.97
==> pack seal
  pack_id: sha256:71cd27ee3a69cf0e5f89cb7f38ce3fc1a3c1788fd67404c416f23daa3d180fc9
==> pack verify
  verify: OK
```

The bundled sample is a marketing-channel spend reconciliation — what your agency reported vs. what actually hit the bank. `shape` confirms the files line up structurally; `rvl` finds the cells that moved; `pack seal` produces a content-addressed receipt you can keep, share, or push to a fabric. Drop the pack directory anywhere, run `pack verify`, and you can prove integrity from member hashes alone. No network, no catalog, no trust.

## Why this exists

Most agent-driven workflows lean on LLM judgment for everything. That's fine for soft questions. For hard questions — "did this number actually change?", "is this evidence pack what you say it is?", "can I prove what I knew when?" — you want **deterministic verdicts with hash-verified provenance**. That's what the [cmdrvl spine](https://github.com/cmdrvl) does, and that's what these skills make accessible in one command.

The spine tools are open source individually. These skills bundle them into a working experience so the value is visible without an installation odyssey.

## Repo layout

```
receipts/
├── skills/
│   ├── receipts-csv/        # focused skill — canonical home of spine + veil scripts
│   │   ├── scripts/         # run-receipt + check-spine + install-spine + setup-veil
│   │   └── assets/
│   └── all-the-receipts/    # umbrella — vendored mirror of receipts-csv scripts
│       ├── scripts/         # mirror of receipts-csv/scripts/ (kept in sync, see AGENTS.md)
│       └── assets/
├── install.sh               # bash bundle installer (calls receipts-csv's install-spine.sh)
├── install.ps1              # PowerShell bundle installer
├── AGENTS.md                # contributor guide — sync rules, invariants
└── README.md
```

## License

MIT. Use it freely. Build on it.

## What's next

Want sealed packs to be discoverable across your fleet — queryable by outcome, provider, lineage? That's what cmdrvl does for clients. Bring the deterministic spine to your data fabric with a metadata catalog connection (part of an outcome retainer or fabric license).

→ See [cmdrvl.com/contact](https://cmdrvl.com/contact)
