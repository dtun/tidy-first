---
name: tidy-audit
description: Scan a window of already-shipped commits and report a ranked cleanup backlog — the "shall we tidy last?" decision applied retrospectively at sprint/feature granularity. Read-only; emits a report, never touches git history. Use when a run of work has left entropy behind, when you want a retrospective cleanup pass over a range of commits, when a sprint or feature shipped and you need a prioritized `refactor:` backlog, or when you want to calibrate future slicing against how tangled the last batch actually shipped.
argument-hint: "<github-commits-url> | <since> [<until>]  [--path <glob>] [--author <name>] [--top <N>]"
license: MIT
metadata:
  author: Danny Tunney
  version: "0.1.0"
---

# Tidy Audit

Scan a **window of shipped commits** and report the **cleanup opportunities** it left behind — a ranked `refactor:` backlog you can act on next. This is the "shall we tidy _last_?" question, applied retrospectively at sprint/feature granularity, to fight the entropy a run of work introduces.

**This skill produces a report. It does not produce a change.** It is read-only: it resolves a commit range, scans the resulting code, detects cleanup opportunities, ranks them, and writes a single markdown report. It never rewrites the working tree, never writes to the target repo, and never touches git history. Any clone it makes is a throwaway read-only copy in a temp dir.

**Two kinds of finding, kept visually separate — never merged.** Some findings are **actionable now** on current code (extract this duplication, thin this handler). Others are **observations only** — a shipped commit that tangled structure with behavior can't be un-tangled without rewriting frozen history, so it is recorded as calibration for *future* slicing, not as work you can do today. Mixing the two would promise a fix that doesn't exist.

**Think in structure/behavior; ship the backlog in conventional commits.** "Entropy," "tangled," and "cleanup" are the *diagnostic lens*. But the team doesn't ship "tidies"; it ships `refactor:`, `test:`, `style:`. So **every finding this skill emits — the ranked table, the per-opportunity block, the proposed message — speaks conventional commits, never the word "tidy."** See the mapping in [TIDIES.md](TIDIES.md#translating-to-conventional-commits).

The question mark in Beck's _Tidy First?_ is load-bearing. This skill does **not** decide what gets cleaned — it lays the opportunities out with their evidence, confidence, and a recommendation, and **the human sets `decision:`** on each one.

## Why this is NOT `tidy-first`

`tidy-audit` is a **sibling** of `tidy-first`, not a mode of it. Different input, different output, different intent. It is closer in spirit to `/code-review` — a reviewer of shipped work — than to `tidy-first`'s forward job on an unshipped change.

| | `tidy-first` | `tidy-audit` |
|---|---|---|
| Operates on | ONE pending change (PR/branch/working tree) | a RANGE of already-shipped commits |
| Question | "how do I split & ship this cleanly?" | "what did this run leave messy — what should we clean next?" |
| Produces | hand-off packages that *reproduce the change* | a ranked cleanup **backlog** (new work) |
| Sibling of | — | `/code-review`, `/review` |
| Touches git? | no (emits prompts) | no (emits a report) |
| Actionable on the input? | yes — you ship the change | no — shipped history is frozen (no amend / no force-push) |

- **Shared asset:** both consume [TIDIES.md](TIDIES.md) — the structural-move catalog and its conventional-commit mapping. `tidy-audit` adds a second catalog, [ANTIPATTERNS.md](ANTIPATTERNS.md), that `tidy-first` does not need.
- **Kept separate on purpose:** so `tidy-first` stays single-responsibility and this stays "not married to tidy-first." Different input, output, and intent — not a flag.
- **Hard boundary:** `tidy-audit` never re-sequences, re-splits, or reproduces shipped commits. Its findings about *tangled shipped commits* are **observations only** — calibration for future slicing, kept visually separate from **actionable** cleanup you can do now.

## Glossary

Use these terms exactly. Catalogs and detection rules in [TIDIES.md](TIDIES.md) and [ANTIPATTERNS.md](ANTIPATTERNS.md).

- **Window** — the range of shipped commits under audit, `base..head`. The unit of input. Everything is scoped to it.
- **Baseline** — the resolved `(target, base..head)`: which repo, which branch, which two commits bound the range. Stated out loud in a one-line summary before any work.
- **Codebase baseline** — the target repo's *own* conventions (declared in docs, or observed in the code), scanned before detection so a finding is judged against what's canonical *here*, not against an assumed-universal rule. A finding cites the convention it violates as part of its `basis:`.
- **Actionable cleanup** — a finding you can do *now* on current code. Lands in the actionable section; carries a proposed `refactor:`/`test:`/`style:` commit.
- **Observation** — a finding about a *shipped* commit that can't be fixed in frozen history (e.g. a tangled `feat:`). Calibration only. Lands in the observations section, never mixed with actionable work.
- **`confidence` + `basis`** — every finding carries `confidence: high | med | low` and a `basis:` — the concrete evidence (the hunks, commits, or convention it rests on). This is a **heuristic** skill; it never claims proven.
- **Entropy delta** — the honest 1–2 sentence gut-check at the top of the report: did this window leave the code messier, and how much?
- **Antipattern** — a debt-introducing shape detected against [ANTIPATTERNS.md](ANTIPATTERNS.md) (duplication, god-file growth, fat entrypoint, …), as opposed to a plain structural opportunity from [TIDIES.md](TIDIES.md).

Key principles:

- **Never claim certainty you don't have.** There is no single stable test suite across a window of commits — the tests changed N times inside it. Every finding is a heuristic guess with a `basis:`; a guess dressed as proof is worse than no finding at all.
- **Grounded beats generic.** A finding backed by an explicit codebase convention (a doc, an ADR, an observed pattern) outranks one fired on a catalog shape alone. If the convention can't be established, the detector drops confidence or is skipped.
- **Actionable and observation never mix.** The value of the split is honesty: one column is work, the other is calibration. Merging them sells a fix for something frozen.
- **It proposes; the human disposes.** Every finding carries a `decision:` stub the human sets. This skill auto-applies nothing.

## Inputs

The resolver is **permissively broad** — accept any of the forms below and normalize internally to a single `(target, base..head)`, so new forms slot in without reworking the process. On ambiguous or unrecognized input, state the assumed baseline and ask before proceeding.

- **GitHub commits URL** — `https://github.com/<owner>/<repo>/commits/<branch>/?since=<date>&until=<date>`. Parse `owner`/`repo`/`branch` from the path and `since`/`until` from the query string. **The target may be a repo you have not checked out** — resolve it against GitHub; do not assume the current directory is the repo.
- **Local range / ref-spec** — `since` / `until` as a duration ("2 weeks"), a ref (`v1.2.0..HEAD`), a date, or a base branch, when run inside the target checkout. Defaults: `since` = `@{7.days.ago}`, `until` = `HEAD`. "A sprint" → default 14 days, or ask.
- **`owner/repo` shorthand + range** — a bare `owner/repo` (optionally `@branch`) with a `since`/`until`, for the remote path without a full URL.

Flags (all forms):

- `--path <glob>` — scope to a subtree (e.g. `apps/mobile/**`).
- `--author <name>` — **informational only**, used solely to detect *cross-author* duplication. Never attribute fault in output. This is not a blame tool.
- `--top <N>` — cap reported opportunities (default 10). If more were found, **log the count dropped** — no silent truncation.

**Baseline one-liner:** state the resolved target out loud, e.g. _"Auditing `dtun/plant-app@main` 2026-07-01..2026-07-03 — 43 commits, 87 files, 4 authors."_ If the range is empty, say so and stop.

## Access model (read-only, agent-neutral)

Get everything through read-only reads — never write to the target or push anything.

- **History & diffs** — for a remote target, resolve commits-in-range and diffs via the GitHub CLI or API (commits in range: `repos/{owner}/{repo}/commits?sha={branch}&since=&until=`; plus per-commit or compare diffs). For a local target, read the existing checkout directly.
- **The tree** — the codebase-baseline scan (below) and the hottest-file structural pass need whole files, not just diffs. For a remote target, obtain them from a **throwaway read-only shallow clone in the OS temp dir** (`$TMPDIR`, fall back to `/tmp`) — never the user's working directory, never a write or push to the source. For a local target, read the checkout in place.

Describe these capabilities generically ("the GitHub CLI or API"; "a throwaway read-only clone") — this skill is agent-neutral.

## Oracle / confidence

This is inherently a **heuristic** skill. There is no single stable test suite across the window — the suite itself changed inside the range — so nothing here is *proven*. Every finding carries `confidence` + `basis:` and never claims certainty.

- **Grounding raises confidence.** A finding backed by an explicit codebase convention (a doc, an ADR, an observed pattern from the codebase baseline) is higher-confidence than one fired on a catalog shape alone.
- **Optional strong check.** If the suite runs on current `HEAD`, a *proposed future* tidy MAY be green-oracle verified against the current tree — that validates the *fix you're proposing now*, not the historical commits. Say which you did.

## Process

### 1. Resolve target, window & baseline

Normalize the input to `(target, base..head)`:

- **GitHub commits URL** → parse `owner`/`repo`/`branch` + `since`/`until`; resolve the range over the GitHub CLI/API; fetch a throwaway read-only clone into `$TMPDIR` for the tree-level steps.
- **Local range / ref-spec** → resolve against the current checkout.
- **`owner/repo` + range** → same as the URL path, without parsing a URL.

Print the **baseline one-liner** naming the resolved target (commits, files, authors). If the range is empty, say so and **stop**.

### 2. Establish codebase context

Before detecting anything, scan the target repo for its **own** conventions, so every detector has a ground truth to judge against instead of an assumed-universal rule. Use a search/exploration subagent. Two sources:

- **Declared conventions** — docs that state the rules: `README`, `AGENTS.md` / `CLAUDE.md`, `CONTEXT.md`, `docs/adr/`, `CONTRIBUTING`, plus config that encodes them (lint/format rules, `tsconfig` path aliases / module boundaries, package layout).
- **Observed patterns** — conventions the code demonstrates but doesn't document: canonical vocabulary/naming, where tests live (colocated vs a `__tests__` dir), where boundary adapters / I·O wrappers already exist, the established public-API / barrel structure.

Emit a short **codebase baseline** the run reasons against. The codebase-relative detectors in [ANTIPATTERNS.md](ANTIPATTERNS.md) (vocabulary drift, broadened public surface, fat entrypoint, unwrapped I/O, and the god-file *threshold*) are only meaningful relative to this baseline — a finding from one of them **must cite the specific convention it violates** as part of its `basis:`. If a convention can't be established, that detector drops to low confidence or is skipped. Never fire it against a rule you assumed.

### 3. Gather signal (read-only, parallelizable)

- **Net diff `base..head`** — what the codebase *gained* across the window.
- **Per-commit metadata** — messages, conventional-commit types (if present), files touched — to detect **tangled commits** (a `feat:` whose diff also contains a pure rename/move) and **churn** (add-then-delete, revert pairs, thrash).
- **Current state of the hottest files** — the most-churned files in the window — for structural smells that only exist in the *aggregate* result, not in any single hunk.

### 4. Detect opportunities

Fan out exploration subagents against the two catalogs; each returns structured findings, every finding grounded in the step-2 codebase baseline and carrying `confidence` + `basis:`:

- **[TIDIES.md](TIDIES.md)** (reused) — extractable duplication, inlinable indirection, rename/vocabulary drift, dead code, reorder/normalize.
- **[ANTIPATTERNS.md](ANTIPATTERNS.md)** (new) — the debt detectors: tangled commit, duplication introduced, god-file growth, fat entrypoint, unwrapped I/O, test-colocation drift, vocabulary drift, add-then-abandon churn, broadened public surface.

### 5. Cluster & dedup

Barrier — needs all findings. Collapse findings that are the same underlying opportunity spread across files or commits into one entry, so the same duplication reported by three subagents becomes a single backlog item.

### 6. Rank & emit the report

Score each finding by `value(entropy reduced) × confidence ÷ effort(blast-radius)`. Keep the top `--top N`; if more were found, **log the number dropped**. Then emit the report per [AUDIT-FORMAT.md](AUDIT-FORMAT.md) — a backlog, not hand-off packages, with the actionable and observation sections kept separate and the human's `decision:` stub on each item. Footer: to *execute* an accepted item, branch it and run `tidy-first` on that branch.

## Non-goals

- **Never** rewrites, amends, rebases, reorders, or reverts history. Read-only; never mutates git state.
- **Never writes to the target/source repo or the user's working tree.** Any clone is a throwaway read-only copy in a temp dir.
- Does **not** reproduce or re-split shipped commits — that is `tidy-first`'s forward job on *unshipped* work.
- **Not** a blame tool — `--author` detects cross-author duplication only; output attributes no fault.
- **Not** a bug or security review — structural/entropy cleanup only; defer correctness to `/code-review`.
- Does **not** auto-apply anything. It proposes; the human sets `decision:`; execution (if any) is a separate `tidy-first` run on a fresh branch.
