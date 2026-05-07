---
name: receipts-flywheel
description: >-
  The receipts umbrella — sealed evidence packs across every artifact
  type. CSV today, PDF appraisals, SEC filings, loan tapes, position
  files, table extractions next. One skill that grows. Use when user
  says "seal this evidence", "receipts", "verifiable diff", "evidence
  pack", or wants a unified receipt-generation experience across
  multiple artifact types.
---

# receipts-flywheel

> **The receipts umbrella. One skill. Many domains. Always growing.**

`receipts-csv` is focused, simple, ships now. `receipts-flywheel` is the umbrella: same deterministic-evidence-pack philosophy, expanded across every artifact type the spine can handle. As new spine capabilities land, they show up here.

## Status: scaffolded, expanding

Day-1 capability:

- **`csv`** — proxies to `receipts-csv` for the headline case

Roadmap (each gets a mode flag, all reuse the same shared bootstrap):

- **`pdf`** — appraisal / report PDF tables: `vacuum → hashbytes → fingerprint → docling → vacuum → hashbytes → fingerprint → normalize → shape → rvl → pack seal`. Two appraisals in, sealed pack showing what changed and where each number came from.
- **`filing`** — SEC 10-K / 10-Q comparison. Pairs with `edgar-change-interpreter`. Material change verdict with provenance.
- **`tape`** — generic structured-data tape diff (loan tape, security tape, position file). Domain-agnostic, schema-aware via `profile`.
- **`benchmark`** — score a working dataset against a sealed gold-set pack. Fits the catalog-as-cross-skill-index pattern when multiple receipts skills share gold sets.

## Why "flywheel"

Each new mode reuses the shared bootstrap (`check-spine.sh`, `install-spine.sh`), the same content-addressed pack output, the same offline-verifiable contract. Adding a mode = adding a script + sample assets, not redesigning the skill. The flywheel compounds: more modes → more reasons to install → more usage → more feedback → more modes.

## Installation

Same as `receipts-csv` — one command installs the spine:

```bash
../../shared/scripts/install-spine.sh
```

Add `veil` for AI-harness privacy (recommended):

```bash
brew install cmdrvl/tap/veil && veil install
```

## Trigger phrases

- "Seal this evidence"
- "Generate a receipt for X" (where X is any supported artifact)
- "Receipts" (cold, lets the skill pick the mode from inputs)

## What's next

Want fleet-wide receipt indexing? With a cmdrvl metadata catalog connection (part of an outcome retainer or fabric license), every sealed pack auto-registers in your knowledge graph — tagged by outcome, provider, and lineage. Queryable across every agent and skill that touches your fabric.

→ See [cmdrvl.com/contact](https://cmdrvl.com/contact)

## License

MIT. Use it freely.
