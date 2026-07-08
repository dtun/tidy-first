# Audit report format

The output of this skill: a **single markdown report** — a ranked cleanup backlog, not hand-off packages. Remember the contract — **this skill produces the report; a later `tidy-first` run produces the change.**

Write the report to the OS temp dir (resolve `$TMPDIR`, fall back to `/tmp`), e.g. `<tmpdir>/tidy-audit-<timestamp>.md`. Nothing lands in the target repo. Tell the user the absolute path.

Two hard rules for the whole report:

- **Actionable and Observations are separate sections, never merged.** Actionable = you can do it now on current code. Observations = tangled/churned *shipped* commits, frozen in history, kept as calibration only.
- **Speaks conventional commits, never the word "tidy."** Every `proposed:` message and the `type` column is `refactor:`/`test:`/`style:`/… — the mapping lives in [TIDIES.md](TIDIES.md#translating-to-conventional-commits).

## Report template

```markdown
# Tidy Audit — <owner>/<repo>@<branch>, <base>..<head>

**Window:** <N> commits · <M> files · <K> authors · <range, e.g. 2026-07-01..2026-07-03>
**Entropy delta:** <honest 1–2 sentence gut-check — did this run leave the code messier, and roughly how much?>
**Reported:** top <N> of <total found> (<dropped> not shown — raise --top to see them)

## Actionable cleanup

Things you can do now on current code. To execute one: branch it and run tidy-first on that branch.

| # | title | type | confidence | effort | blast-radius | why-now |
|---|-------|------|------------|--------|--------------|---------|
| 1 | Extract shared cart validation | refactor | high | S | 3 files | added twice this window by 2 authors |
| 2 | Wrap new Stripe call in an adapter | refactor | med | M | 1 module | new I/O with no mock point |
| 3 | Add test for PriceBadge | test | high | S | 1 file | shipped without a colocated test |

### 1 — Extract shared cart validation
- **type:**       refactor
- **confidence:** high
- **basis:**      near-identical 18-line block in `cart/checkout.ts:44` and `cart/quickbuy.ts:71`, added in `a1b2c3d` and `e4f5g6h` by different authors; past the rule of three with the pre-existing copy in `cart/api.ts:20`.
- **location:**   cart/checkout.ts:44-61 · cart/quickbuy.ts:71-88 · cart/api.ts:20-37
- **evidence:**   commits a1b2c3d, e4f5g6h (window); the third site predates the window.
- **proposed:**   `refactor: extract validateCart from checkout, quickbuy, api`
- **decision:**   do-now | backlog | wontfix        # ← HUMAN SETS THIS. recommendation: do-now (three drifting copies)

### 2 — Wrap new Stripe call in an adapter
- **type:**       refactor
- **confidence:** med
- **basis:**      direct `stripe.charges.create(...)` at `billing/charge.ts:30` (added in `b2c3d4e`); repo's other external calls go through `lib/adapters/*` (codebase baseline), this one bypasses that seam.
- **location:**   billing/charge.ts:30
- **evidence:**   commit b2c3d4e (window).
- **proposed:**   `refactor: route Stripe charge through a billing adapter`
- **decision:**   do-now | backlog | wontfix        # ← HUMAN SETS THIS. recommendation: backlog (isolated, low churn)

## Observations (not actionable — shipped history is frozen)

Calibration only: tangled or churned commits already shipped. Not fixable without rewriting history — recorded so future slicing (via tidy-first) improves. No decision to make here.

- **Tangled commit `a1b2c3d`** — typed `feat: add quick-buy` but its diff also contains a pure rename (`qty` → `quantity`) across 4 files. Review saw the rename noise mixed with the behavior. *Next time:* split the rename into its own `refactor:` ahead of the feature.
- **Churn on `promo/engine.ts`** — added in `c3d4e5f`, ~70% rewritten in `f6g7h8i` two days later. Premature abstraction; the survivor still carries the abandoned config shape (see actionable item for the simplification, if any).
```

## Rules for filling it in

- **Every finding carries `confidence` + `basis`.** `basis:` is the concrete evidence — the specific hunks, commits, or codebase convention the finding rests on. This is a heuristic skill; there is no "proven." A codebase-relative finding must cite the convention it violates (see [ANTIPATTERNS.md](ANTIPATTERNS.md)).
- **`type` is the conventional commit.** `refactor:` for most structural cleanup; `test:`/`style:` only when the change is purely that. Never the word "tidy," in any field.
- **`decision:` is always the human's** — `do-now | backlog | wontfix`, pre-filled with a recommendation and a one-line why, left for them to set. This skill applies nothing.
- **Ranked table is keyed by conventional-commit `type`** — never "tidy"/"behavioral." `effort` is S/M/L; `blast-radius` is the reach of the change (files/modules affected); `why-now` is the one-line justification.
- **Observations get no `decision:` and no `proposed:` fix.** They are frozen history — calibration, not work. Keep them physically below the actionable section so the two are never conflated.
- **No silent truncation.** If `--top N` dropped findings, say how many in the header. If a detector was skipped because its codebase convention couldn't be established, note that rather than omitting it silently.

## Footer

Close the report with the execution path — this skill stops at the report:

> To act on an accepted item: branch it (`git switch -c refactor/<slug>`) and run `tidy-first` on that branch. This audit changes nothing on its own.
