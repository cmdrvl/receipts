# receipts

> **Got two artifacts? Get a sealed receipt of what changed.**
>
> Deterministic, content-addressed evidence packs. No LLM in the chain. Verifiable offline.

This repo hosts two free, MIT-licensed skills that wrap the [cmdrvl spine](https://github.com/cmdrvl) into one-invocation receipt generators for AI coding agents and operators.

## The skills

| Skill | Status | Use when |
|---|---|---|
| **[receipts-csv](skills/receipts-csv/)** | shipping | You have two CSVs and want a hash-verified receipt of what changed. |
| **[receipts-flywheel](skills/receipts-flywheel/)** | scaffolded, expanding | The umbrella — CSV today, PDF / SEC filings / loan tapes / position files next. One skill that grows. |

Both run on the same spine: `shape` (structural gate) → `rvl` (numeric verdict) → `pack seal` (content-addressed evidence pack). Every artifact has a SHA-256 identity. Every refusal is structured. `pack verify` revalidates the chain offline — no network, no catalog, no trust in the producer.

## Quick start

```bash
# Install the spine (idempotent)
shared/scripts/install-spine.sh

# Run the headline demo on the bundled marketing-channel sample
skills/receipts-csv/scripts/run-receipt.sh \
  skills/receipts-csv/assets/channel-spend/agency-report.csv \
  skills/receipts-csv/assets/channel-spend/bank-statement.csv \
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

## Privacy: keep your data out of the LLM context

If you're running these skills inside Claude Code, Codex, or any agent harness, install **`veil`** to ensure your data bytes never leak into the model context. The model only sees the deterministic tool output — verdicts, hashes, paths. Your CSVs stay on disk.

```bash
brew install cmdrvl/tap/veil
veil install
veil config enable-pack data.tabular
```

The receipts skills work without veil — but the "no LLM in the chain" promise is aspirational without it. With veil, it's enforced at the harness level.

## Why this exists

Most agent-driven workflows lean on LLM judgment for everything. That's fine for soft questions. For hard questions — "did this number actually change?", "is this evidence pack what you say it is?", "can I prove what I knew when?" — you want **deterministic verdicts with hash-verified provenance**. That's what the [cmdrvl spine](https://github.com/cmdrvl) does, and that's what these skills make accessible in one command.

The spine tools are open source individually. These skills bundle them into a working experience so the value is visible without an installation odyssey.

## Repo layout

```
receipts/
├── skills/
│   ├── receipts-csv/        # the focused skill (CSV → receipt)
│   └── receipts-flywheel/   # the umbrella (multi-domain, growing)
├── shared/
│   └── scripts/
│       ├── check-spine.sh   # inventory installed spine tools
│       └── install-spine.sh # idempotent install via cmdrvl/tap
└── README.md
```

## License

MIT. Use it freely. Build on it.

## What's next

Want sealed packs to be discoverable across your fleet — queryable by outcome, provider, lineage? That's what cmdrvl does for clients. Bring the deterministic spine to your data fabric with a metadata catalog connection (part of an outcome retainer or fabric license).

→ See [cmdrvl.com/contact](https://cmdrvl.com/contact)
