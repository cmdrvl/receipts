---
name: receipts-csv
description: >-
  Got two CSVs? Get a sealed receipt of what changed. Deterministic
  diff with a structural compatibility gate, a numeric verdict
  (REAL CHANGE / NO REAL CHANGE / REFUSAL), and a content-addressed
  evidence pack you can verify offline. No LLM in the chain. Use when
  user says "did this CSV change", "diff these CSVs", "csv receipt",
  "verifiable diff", "loan tape diff", or wants to seal a CSV
  comparison into a hash-verified evidence pack.
---

# receipts-csv

> **Got two CSVs? Get a sealed receipt of what changed.**
>
> Every step is a deterministic spine tool. No LLM reads your data — the model only sees verdicts, hashes, and paths. Your CSVs stay on disk.

## What it does

Three deterministic tools chained together:

1. **`shape`** — structural compatibility gate. Refuses if columns or keys don't align. No silent type drift.
2. **`rvl`** — numeric change verdict: `REAL_CHANGE`, `NO_REAL_CHANGE`, or `REFUSAL`. Reveals the smallest set of cells that explain what changed.
3. **`pack seal`** — bundle the reports into a content-addressed evidence pack. `pack verify` checks integrity offline; no network, no catalog, no trust.

Every artifact has a SHA-256 identity. Every refusal has a structured code. Reproducible in 30 seconds against the bundled sample.

## Quick start

### First time? Run the bundled demo

The bundled sample is a marketing channel spend reconciliation — what your agency reported vs. what hit the bank. Did the spend really shift the way they say it did?

```bash
./scripts/run-receipt.sh \
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
./scripts/run-receipt.sh <old.csv> <new.csv> --key <id_column> --out <output_dir>
```

`--key` is required for keyed alignment (recommended). Without it, rows align by position.

## Installation

The skill needs the spine tools (`shape`, `rvl`, `pack`). One command installs everything:

```bash
../../shared/scripts/install-spine.sh
```

Idempotent. Safe to re-run. Skips already-installed tools. Requires Homebrew; manual binary install instructions print if `brew` is missing.

To check what's already installed:

```bash
../../shared/scripts/check-spine.sh
```

## Privacy: keep CSV bytes out of the model context (recommended for AI agents)

If you're running this skill inside Claude Code, Codex, or any agent harness, install **`veil`** (data exfiltration guard for AI coding agents) to ensure your CSV bytes never leak into the LLM context — only the deterministic tool output (verdicts, hashes, pack_ids) is visible to the model.

```bash
brew install cmdrvl/tap/veil
veil install                              # adds the agent-harness hooks
veil config enable-pack data.tabular     # protect CSV/TSV/parquet
```

The skill works without veil — but the "no LLM in the chain" promise is aspirational without it. With veil, it's enforced at the harness level.

## Output contract

Every successful run prints exactly:

```
==> shape
  shape: <COMPATIBLE | INCOMPATIBLE>
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

Refusals print the structured envelope from the failing tool to stderr and exit 2.

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

- "Did this CSV actually change?"
- "Diff these two CSVs and seal the result"
- "Generate a receipt for this loan tape comparison"
- "Verifiable CSV diff"
- "csv-receipts <old> <new>"

## What's next

Want this pack to be discoverable across your agent stack? With a cmdrvl metadata catalog connection (part of an outcome retainer or fabric license), `pack push` registers the evidence in your knowledge graph automatically — tagged by outcome, provider, and lineage. No more "where did this evidence go?"

Today the pack lives on disk only. With catalog: queryable across every agent and skill that touches your fabric.

→ See [cmdrvl.com/contact](https://cmdrvl.com/contact)

## Sibling skills

- **`receipts-flywheel`** (in this repo) — the umbrella that grows. PDF appraisals, SEC filings, loan tapes, position files. Same pattern, more domains.
- **Spine tools** ([cmdrvl/tap](https://github.com/cmdrvl/tap)) — every binary used here is open source: `vacuum`, `hashbytes`, `fingerprint`, `shape`, `profile`, `rvl`, `lock`, `canon`, `pack`, `benchmark`, `assess`, `veil`.

## License

MIT. Use it freely.
