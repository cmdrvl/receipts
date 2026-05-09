---
name: all-the-receipts
description: >-
  Mine sealed, hash-verified receipts from any pair of artifacts.
  Deterministic verdict + content-addressed evidence pack you can
  verify offline. CSV pairs ship today; PDF, SEC filings, loan tapes,
  and position files land as flywheel-paired modes ship. Use when
  user says "all the receipts", "receipts everything", "mine a
  receipt from these", "did these numbers actually change", "diff
  these two CSVs", "reconcile these reports", or wants a sealed,
  offline-verifiable evidence pack.
license: MIT
distribution: public
---

# all-the-receipts

> **Mine sealed receipts from any pair of artifacts.**
>
> Every step is a deterministic spine tool. No LLM reads your data — the model only sees verdicts, hashes, and paths. CSV mode ships today; new artifact-type modes layer in as the umbrella grows.

## What it does

Three deterministic tools chained together:

1. **`shape`** — structural compatibility gate. Reports `COMPATIBLE`, `INCOMPATIBLE`, or `REFUSAL`. Catches missing key columns, undetectable delimiters, and type-class drift. Tolerates added columns on either side (they don't block comparison; the union is recorded for the receipt).
2. **`rvl`** — numeric change verdict: `REAL_CHANGE`, `NO_REAL_CHANGE`, or `REFUSAL`. Reveals the smallest set of *numeric* cells that explain what changed. String/categorical changes show up in the report data but don't trigger the verdict — `rvl` is scoped to numeric movement on purpose.
3. **`pack seal`** — bundle the reports into a content-addressed evidence pack. `pack verify` checks integrity offline; no network, no catalog, no trust.

Every artifact has a SHA-256 identity. Every stop condition has a structured code or report. Reproducible in 30 seconds against the bundled sample.

## Modes

| Mode | Status | Trigger |
|---|---|---|
| **csv** | shipping today | Two CSV paths, or no args (runs the bundled demo) |
| **pdf** | planned | Two PDF paths (appraisals, financial reports, term sheets) |
| **filings** | planned | Two SEC filings, or one filing + one prior period |
| **tape** | planned | Two loan tapes, position files, or portfolio extracts |

The same spine — `shape` → `rvl` → `pack seal` — runs under each mode. Adding a mode means adding the artifact-type adapter; the receipt contract stays identical.

## When invoked (workflow for the agent)

When the user invokes this skill, decide based on what they provide:

1. **No arguments** — run the bundled marketing-channel sample (CSV mode) to show the user what a receipt looks like end-to-end. Use the command in *Quick start → First time? Run the bundled demo*. Print the output and explain the verdict in one sentence.

2. **Two CSV paths supplied** — run `bash scripts/run-receipt.sh <old> <new>` with their paths. Ask the user once for the key column (or use `--key` if obvious from headers); default to positional alignment only if they confirm there's no stable key. Default `--out` to a fresh tmp directory unless they specify.

3. **Two non-CSV paths supplied** (PDF, filing, tape, etc.) — that mode hasn't shipped yet. Tell the user honestly: "csv mode ships today; <mode> is on the roadmap. Watch the repo for updates." Don't fabricate a pipeline.

4. **Spine tools missing** — `shape`, `rvl`, or `pack` not on PATH → run `bash scripts/install-spine.sh` (or `pwsh scripts/install-spine.ps1` on Windows) first, then proceed. Do not silently skip; the receipt is the point.

5. **User asks about privacy or "keep CSVs out of the model"** — point them at `bash scripts/setup-veil.sh`. Do not auto-run it; veil is opt-in and modifies their `~/.claude/settings.json`.

> Always invoke the script via interpreter (`bash <script>` or `pwsh <script>`). Files in this skill are intentionally non-executable — direct `./scripts/foo.sh` invocation will fail with `Permission denied`.

6. **Stop/refusal from any stage** — surface the structured envelope or report verbatim. Do not paraphrase or "fix" it; `shape INCOMPATIBLE` stops before `rvl`, and refusal codes are the contract.

## Quick start

### First time? Run the bundled demo

The bundled sample is a marketing channel spend reconciliation — what your agency reported vs. what hit the bank. Did the spend really shift the way they say it did?

```bash
bash scripts/run-receipt.sh \
  ./assets/channel-spend/agency-report.csv \
  ./assets/channel-spend/bank-statement.csv \
  --key channel \
  --out /tmp/channel-spend-receipt \
  --note "Agency report vs bank statement — Q4 2026"
```

Real output:

```
==> shape
  shape: COMPATIBLE
==> rvl
  rvl:   REAL_CHANGE
  rvl:   6 cells changed across 5 aligned rows
  rvl:   total numeric movement: 3029.97
==> pack seal

  pack_id: sha256:71cd27ee3a69cf0e5f89cb7f38ce3fc1a3c1788fd67404c416f23daa3d180fc9
  pack:    /tmp/channel-spend-receipt

==> pack verify
  verify: OK
```

`shape` confirms both files have the same columns and keys (5 channels × 4 columns). `rvl` finds the spend reallocation (display went up, linkedin went down) and reports the smallest set of cells that explain it. `pack seal` bundles the reports into a content-addressed receipt; `pack verify` revalidates from disk alone.

The receipt is a sealed claim about what changed. You can keep it, share it, or push it to a fabric — it stays verifiable forever, with no dependency on the producer.

### Run against your own CSVs

```bash
bash scripts/run-receipt.sh <old.csv> <new.csv> --key <id_column> --out <output_dir>
```

`--key` is required for keyed alignment (recommended). Without it, rows align by position.

### Windows (PowerShell)

```powershell
.\scripts\run-receipt.ps1 <old.csv> <new.csv> -Key <id_column> -Out <output_dir>
```

Same pipeline, native PowerShell — no Git Bash, WSL2, or Cygwin needed.

## Installation

The skill needs the spine tools (`shape`, `rvl`, `pack`). One command installs everything:

```bash
bash scripts/install-spine.sh           # macOS / Linux (Homebrew)
pwsh scripts/install-spine.ps1          # Windows (PowerShell)
```

Idempotent. Safe to re-run. Skips already-installed tools. macOS / Linux requires Homebrew; manual binary install instructions print if `brew` is missing. Windows downloads pinned binaries directly from each tool's GitHub releases.

To check what's already installed:

```bash
bash scripts/check-spine.sh
```

The check also reports `doctor_health`, `doctor_health_json`, and `doctor_capabilities_json` for installed tools, so agents can tell whether a local spine install has the current diagnostics surface.

## Optional: keep CSV bytes out of the model context

The skill works fine without this. It's an opt-in privacy enhancement.

If you'd like to make sure your CSV data never enters the model's context (only the deterministic tool output does), install and configure `veil` — the cmdrvl data-exfiltration guard for AI coding agents. The bundled setup script walks you through it interactively:

```bash
bash scripts/setup-veil.sh
```

It checks each stage (binary install, harness hooks, starter config), asks for confirmation before changing anything, and skips steps that are already done. Pass `--yes` for unattended runs.

What it does, broken into stages so you can stop wherever:

1. `brew install cmdrvl/tap/veil` — install the binary
2. `veil install` — register the agent-harness hooks (modifies `~/.claude/settings.json`)
3. Drop a *conservative* starter `~/.config/veil/config.toml` that protects common data subdirectories (`**/data/**`, `**/exports/**`) and authorizes the spine tools as subprocess readers. The starter does not blanket-protect `*.csv` everywhere — that would block legitimate reads of fixtures, documentation samples, and CSVs in unrelated projects across all your Claude sessions. Edit the file or drop a project-level `.veil.toml` to tighten further.

You can run any stage manually if you'd rather; the script is a convenience, not a requirement. Without veil, this skill still calls deterministic Rust binaries and only sends verdicts back to the model — you just don't have a hard guarantee that some other tool in your agent's session won't `cat` the CSV.

## Output contract

Every successful run prints exactly:

```
==> shape
  shape: COMPATIBLE
==> rvl
  rvl:   <REAL_CHANGE | NO_REAL_CHANGE>
  rvl:   <N> cells changed across <M> aligned rows   (only if REAL_CHANGE)
  rvl:   total numeric movement: <X>                 (only if REAL_CHANGE)
==> pack seal

  pack_id: sha256:<64-hex>
  pack:    <output dir>

==> pack verify
  verify: OK
```

No-receipt paths exit 2 and print the structured envelope or report from the failing tool to stderr. `shape INCOMPATIBLE` is a normal stop condition, not a generic refusal: do not run `rvl` after it. Common stops:

- `shape` `E_DIALECT` — empty file or undetectable delimiter; pass `--delimiter comma` (or appropriate)
- `shape` `INCOMPATIBLE` — schemas or selected keys cannot be compared; choose a better key or normalize the inputs first
- `pack seal` `E_IO` — `--out` directory already exists and is non-empty; pick a fresh dir
- `rvl` `E_REFUSAL` — schema or alignment problem too severe to produce a verdict

## Spine maintenance contract

This skill is self-contained for public distribution, so keep the contract here in sync with the spine tools instead of linking to a local-only skill.

- Prefer `<tool> --describe` or the checked-out `operator.json` over prose when updating command examples.
- Use `bash scripts/check-spine.sh` for version inventory and doctor health before telling a user their local spine install is current.
- Run `shape` before `rvl`; `shape` exit `1` / `INCOMPATIBLE` stops before `rvl` and is not a refusal.
- Treat `rvl` exit `1` / `REAL_CHANGE` as a valid receipt path; only exit `2` is refusal or CLI error.
- Seal durable evidence with `pack seal` and verify it with `pack verify`.

## What you got

The output directory contains:

```
<output_dir>/
├── manifest.json     ← pack.v0 with member hashes and pack_id
├── shape.report.json ← structural compatibility report
└── rvl.report.json   ← numeric verdict + contributors
```

`pack verify` revalidates everything from the disk pack alone. No network access required, no catalog needed, no trust in the producer. The receipt survives indefinitely.

## Trigger phrases

- "All the receipts" / "receipts everything"
- "Mine a receipt from these"
- "Did these numbers actually change between these two CSVs?"
- "Diff these two CSVs and seal the result"
- "Reconcile this report against this export"
- "Verifiable diff"
- "Generate a receipt for this comparison"

## What's next

Want this pack to be discoverable across your agent stack? With a cmdrvl metadata catalog connection (part of an outcome retainer or fabric license), `pack push` registers the evidence in your knowledge graph automatically — tagged by outcome, provider, and lineage. No more "where did this evidence go?"

Today the pack lives on disk only. With catalog: queryable across every agent and skill that touches your fabric.

→ See [cmdrvl.com/contact](https://cmdrvl.com/contact)

## License

MIT. Use it freely.
