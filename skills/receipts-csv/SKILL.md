---
name: receipts-csv
description: >-
  Got two CSVs? Get a sealed receipt of which numbers changed.
  Deterministic diff with a structural compatibility gate, a numeric
  verdict (REAL_CHANGE / NO_REAL_CHANGE / REFUSAL), and a content-
  addressed evidence pack you can verify offline. No LLM reads your
  data. Use when user says "did these numbers change", "diff these
  CSVs", "csv receipt", "verifiable CSV diff", "reconcile these
  two reports", or wants to seal a CSV comparison into a hash-verified
  evidence pack.
---

# receipts-csv

> **Got two CSVs? Get a sealed receipt of what changed.**
>
> Every step is a deterministic spine tool. No LLM reads your data — the model only sees verdicts, hashes, and paths. Your CSVs stay on disk.

## What it does

Three deterministic tools chained together:

1. **`shape`** — structural compatibility gate. Reports `COMPATIBLE` or `REFUSAL`. Catches missing key columns, undetectable delimiters, and type-class drift. Tolerates added columns on either side (they don't block comparison; the union is recorded for the receipt).
2. **`rvl`** — numeric change verdict: `REAL_CHANGE`, `NO_REAL_CHANGE`, or `REFUSAL`. Reveals the smallest set of *numeric* cells that explain what changed. String/categorical changes show up in the report data but don't trigger the verdict — `rvl` is scoped to numeric movement on purpose.
3. **`pack seal`** — bundle the reports into a content-addressed evidence pack. `pack verify` checks integrity offline; no network, no catalog, no trust.

Every artifact has a SHA-256 identity. Every refusal has a structured code. Reproducible in 30 seconds against the bundled sample.

## When invoked (workflow for the agent)

When the user invokes this skill, decide based on what they provide:

1. **No arguments** — run the bundled marketing-channel sample to show the user what the receipt looks like end-to-end. Use the command in *Quick start → First time? Run the bundled demo*. Print the output and explain the verdict in one sentence.

2. **Two CSV paths supplied** — run `bash scripts/run-receipt.sh <old> <new>` with their paths. Ask the user once for the key column (or use `--key` if obvious from headers); default to positional alignment only if they confirm there's no stable key. Default `--out` to a fresh tmp directory unless they specify.

3. **Spine tools missing** — `shape`, `rvl`, or `pack` not on PATH → run `bash scripts/install-spine.sh` (or `pwsh scripts/install-spine.ps1` on Windows) first, then proceed. Do not silently skip; the receipt is the point.

4. **User asks about privacy or "keep CSVs out of the model"** — point them at `bash scripts/setup-veil.sh`. Do not auto-run it; veil is opt-in and modifies their `~/.claude/settings.json`.

> Always invoke the script via interpreter (`bash <script>` or `pwsh <script>`). Files in this skill are intentionally non-executable — direct `./scripts/foo.sh` invocation will fail with `Permission denied`.

5. **Refusal from any stage** — surface the structured refusal envelope verbatim. Do not paraphrase or "fix" it; the refusal codes are the contract.

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

## Installation

The skill needs the spine tools (`shape`, `rvl`, `pack`). One command installs everything:

```bash
bash scripts/install-spine.sh           # macOS / Linux (Homebrew)
pwsh scripts/install-spine.ps1          # Windows (PowerShell)
```

Idempotent. Safe to re-run. Skips already-installed tools. Requires Homebrew; manual binary install instructions print if `brew` is missing.

To check what's already installed:

```bash
bash scripts/check-spine.sh
```

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

Refusal paths exit 2 and print the structured envelope from the failing tool to stderr. Common refusals:

- `shape` `E_DIALECT` — empty file or undetectable delimiter; pass `--delimiter comma` (or appropriate)
- `pack seal` `E_IO` — `--out` directory already exists and is non-empty; pick a fresh dir
- `rvl` `E_REFUSAL` — schema or alignment problem too severe to produce a verdict

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

- "Did these numbers actually change between these two CSVs?"
- "Diff these two CSVs and seal the result"
- "Reconcile this report against this export"
- "Verifiable CSV diff"
- "Generate a receipt for this comparison"
- "csv-receipts <old> <new>"

## What's next

Want this pack to be discoverable across your agent stack? With a cmdrvl metadata catalog connection (part of an outcome retainer or fabric license), `pack push` registers the evidence in your knowledge graph automatically — tagged by outcome, provider, and lineage. No more "where did this evidence go?"

Today the pack lives on disk only. With catalog: queryable across every agent and skill that touches your fabric.

→ See [cmdrvl.com/contact](https://cmdrvl.com/contact)

## Sibling skills

- **`all-the-receipts`** (in this repo) — umbrella that runs the same CSV pipeline today and grows to cover PDF, SEC filings, loan tapes, and position files as flywheel-paired modes ship. Pick `receipts-csv` for the focused, single-purpose tool; pick `all-the-receipts` if you want one skill that grows across artifact types.
- **Spine tools** ([cmdrvl/tap](https://github.com/cmdrvl/tap)) — every binary used here is open source: `vacuum`, `hashbytes`, `fingerprint`, `shape`, `profile`, `rvl`, `lock`, `canon`, `pack`, `benchmark`, `assess`, `veil`.

## License

MIT. Use it freely.
