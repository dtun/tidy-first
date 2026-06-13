# Hand-off package format

The output of this skill. One package per step in the sequence. A package is a **self-contained prompt**: the receiving agent should be able to execute it with no other context. Remember the contract — **this skill produces the package; the receiver produces the change.**

Write packages to the OS temp dir (resolve `$TMPDIR`, fall back to `/tmp`), one file per step, e.g. `<tmpdir>/tidy-first-<timestamp>/step-01-extract-validateCart.md`. Nothing lands in the repo. Tell the user the absolute path.

## Per-step template

```markdown
# Step <n> — <short title>

type:        feat | fix | refactor | test | style | docs | chore   # conventional commit
commit:      <type>: <imperative subject line the receiver should use>
nature:      structural | behavioral      # the lens, kept for traceability only — NOT user-facing
transform:   <the precise move, e.g. "extract method validateCart">
             (for feat/fix: state the behavior change in one line instead)
decision:    refactor-first | refactor-last | skip   # ← HUMAN SETS THIS (refactor steps only). recommendation pre-filled.
recommended: refactor-first                          # why: <one line>
verified:    proven-green | unverified: <reason>
depends_on:  [<step numbers>]                         # empty if independent

## Scope
- <file>:<line-range> — <what changes here>
- ...
(precise enough to apply unambiguously; quote the before/after hunk if small)

## Transform
<plain-English description of exactly what to do, with the precise structural move named.
 For an untangle, this is ONE state in the chain — describe only this state.>

## Verification
Run: `<exact command, e.g. pnpm test src/cart>`
Expect: for a `refactor:`, all existing tests pass UNCHANGED. If any test needs to change
to pass, STOP — this was misclassified as structural (it's really a `feat:`/`fix:`). Report back.

## Ship
<the recommended landing, e.g. "commit `refactor: extract validateCart`,
 merge to main ahead of the feat PR">
```

## Rules for filling it in

- **`refactor:` packages must be pure.** If the receiver finds it can't go green without editing a test, the change wasn't structural — it's a `feat:`/`fix:`. The package tells it to stop and report, not to push through.
- **`type:` is the conventional commit; `nature:` is the lens.** Lead with `type:`. Keep `nature: structural|behavioral` only as an internal breadcrumb — it never reaches a commit, PR, or anything the user reads.
- **`verified:`** is `proven-green` only in the strong tier where you actually ran the suite against the materialized state. Otherwise `unverified: <reason>` (e.g. `intermediate not built`, `no test env`). Never label a heuristic guess as proven.
- **`decision:`** is always the human's, and only meaningful on `refactor:` steps (a `feat:` ships in its slot). Pre-fill `recommended:` with your call and a one-line why; leave `decision:` for them. Don't execute a `skip`; don't reorder around a decision the human hasn't set.
- **Untangled chains** become consecutive steps with `depends_on` pointing back — the `refactor:` commit first, the `feat:`/`fix:` after, each independently green.
- **One concern per package.** If a package mixes a `refactor:` and a `feat:`, it wasn't untangled — go back to step 3 of the process.

## Sequence summary

Alongside the per-step files, print one table so the human can decide at a glance:

| # | type | commit | verified | depends_on | recommended |
|---|------|--------|----------|------------|-------------|
| 1 | refactor | `refactor: extract validateCart` | proven-green | — | refactor-first |
| 2 | refactor | `refactor: rename qty → quantity` | proven-green | — | refactor-first |
| 3 | feat | `feat: reject carts over limit` | — | [1] | (in feat PR) |

The table is keyed by **conventional-commit type** — never "tidy"/"behavioral." Lead with the recommended path and its payoff in concrete terms — e.g. _"land the two `refactor:` steps on `main`; your `feat:` PR shrinks to the step-3 diff against clean code, and the extraction is revertible on its own if it proves wrong."_ Then hand control back to the human to set the `decision:` fields on the `refactor:` steps.
