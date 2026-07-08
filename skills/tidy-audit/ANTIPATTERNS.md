# Antipatterns — the detector catalog

The debt detectors `tidy-audit` runs against a window of shipped commits. Where [TIDIES.md](TIDIES.md) catalogs *structural moves* (the fix), this catalogs *debt shapes* (the smell) — what a run of work tends to leave behind.

**This catalog is additive, not a replacement.** The audit detects against *both* catalogs (SKILL.md step 4): [TIDIES.md](TIDIES.md) supplies the structural opportunities `tidy-first` already knows *and* the resolving move for each finding here; this file adds the smells you can only see over a **window of history** — several of which (tangled commit, churn, cross-author duplication, threshold-crossing growth) are properties of the *commit stream*, not of any single hunk, so a per-hunk move catalog can't express them. You **search** for a smell here; you **propose** a tidy from there. Every `→ resolving refactor:` below is a TIDIES move.

Each detector is: **name** · `signal` (how it's found) · `debt` (why it costs) · `→ resolving refactor:` (the conventional-commit fix). Detectors are independently toggleable, and this catalog is meant to be **extended by the repo** — add your own shapes below the seed set.

## The catalog is shapes, not a rulebook

A detector names *what shape of debt to look for*. It does **not** know what's canonical in your codebase — that comes from the **codebase baseline** the audit establishes first (SKILL.md step 2: the repo's own docs and observed patterns). So each detector is tagged:

- **absolute** — fires on a structural fact alone (a commit's type disagrees with its diff; the same block appears twice). No baseline needed.
- **codebase-relative** — meaningless without the baseline. "Drift," "fat," "broadened," and "too big" are all *relative to what this repo already does*. A codebase-relative detector **names where to source its ground truth**, cites the specific convention it violates as part of the finding's `basis:`, and — if that convention can't be established — drops to low confidence or is **skipped**. Never fire one against an assumed-universal rule.

> A false "this is debt" that rests on a rule the repo never adopted is worse than a miss. When unsure whether a convention exists, say so and lower the confidence — don't invent the rule to justify the finding.

## Seed detectors

### 1. Tangled commit  ·  absolute  ·  **observation only**
- `signal:` a commit's conventional-commit type disagrees with its hunk classification — e.g. a `feat:` whose diff also contains a pure rename/move, or a `refactor:` that changes behavior.
- `debt:` review saw noise, not the behavior; the structural and behavioral change can't be reverted independently.
- `→` **Observation, not actionable.** Shipped history is frozen — do not propose a re-split. Record it as calibration for *future* slicing (this is what `tidy-first` prevents going forward).

### 2. Duplication introduced  ·  absolute (cross-author lens uses `--author`)
- `signal:` near-identical blocks added within the window, especially by *different* authors (the multi-author drift this tool fights). Use `--author` to detect cross-author copies — never to attribute fault.
- `debt:` a change now has to be made in N places; the copies drift apart.
- `→` AHA-gate against the rule of three: if the window pushed it *past* three sites, `refactor:` extract the shared unit; if not yet, leave it and note the count so the next audit can call it.

### 3. God-file / growth  ·  codebase-relative (threshold)
- `signal:` a file crossed a size / responsibility threshold *this window* — measured against the repo's own norms (typical file size, one-responsibility-per-module convention), not a hard-coded line count.
- `ground truth:` the codebase baseline's sense of normal module size and the declared module boundaries (`tsconfig` paths, package layout, ADRs on structure).
- `debt:` the file is now a merge-conflict magnet and hard to navigate.
- `→` `refactor:` extract a module along a responsibility seam.

### 4. Fat entrypoint  ·  codebase-relative
- `signal:` logic added directly to a route / handler / CLI command / framework entrypoint, rather than to a testable unit behind it.
- `ground truth:` where this repo *already* puts business logic vs entrypoints (the observed feature/handler split; any "keep handlers thin" convention in docs).
- `debt:` the logic can't be tested without simulating the entrypoint.
- `→` `refactor:` extract the logic into a feature/unit and thin the entrypoint to a call.

### 5. Unwrapped I/O  ·  codebase-relative
- `signal:` a new network / filesystem / clock / SDK / native call made directly, not behind a boundary adapter.
- `ground truth:` where the repo's existing boundary adapters / I·O wrappers live (observed in step 2). If the repo has no adapter convention at all, this is low confidence — note it rather than asserting it.
- `debt:` an I/O seam with no mock point; tests must hit the real dependency.
- `→` `refactor:` wrap the call in an adapter that matches the repo's existing seam (also improves testability).

### 6. Test-colocation drift  ·  absolute (location convention from baseline)
- `signal:` a new component/feature shipped without a colocated test, or a test that has drifted away from the code it covers.
- `ground truth:` the repo's test-placement convention (colocated `*.test.ts` vs a `__tests__`/`tests/` dir) — read from the baseline so "missing" and "misplaced" mean the right thing here.
- `debt:` the new surface is unverified, or the test is stranded from its subject.
- `→` `test:` add or move the test to the canonical location.

### 7. Vocabulary drift  ·  codebase-relative
- `signal:` new names inconsistent with the codebase's established terms (a new `fetchUser` beside an established `loadUser`; a new spelling of a domain noun).
- `ground truth:` the canonical vocabulary in the codebase baseline (domain terms in `CONTEXT.md`/ADRs, dominant naming in the code). Cite the canonical term the new name drifted *from*.
- `debt:` two words for one concept; readers and search fracture.
- `→` `refactor:` rename to the canonical vocabulary.

### 8. Add-then-abandon / churn  ·  absolute
- `signal:` code added early in the window and mostly deleted or rewritten later within it (add-then-delete, revert pairs, thrash on the same lines).
- `debt:` premature abstraction; a survivor still carries scaffolding built for the abandoned version.
- `→` `refactor:` simplify the survivor down to what it actually needs now.

### 9. Broadened public surface  ·  codebase-relative
- `signal:` new deep imports or barrel bypasses — callers reaching past the module's public entry into its internals.
- `ground truth:` the established public-API / barrel structure and any module-boundary config (`tsconfig` paths, lint import rules) from the baseline.
- `debt:` the module's internals are now load-bearing for outside callers; refactoring it breaks them.
- `→` `refactor:` tighten the public API — route callers through the intended entry, re-encapsulate the internals.

## Extending the catalog

Add repo-specific detectors below in the same shape (**name** · `signal` · `debt` · `→ refactor:`), and tag each **absolute** or **codebase-relative**. Prefer codebase-relative detectors that lean on your `CONTEXT.md` / ADRs — a detector grounded in a written convention produces higher-confidence, less-arguable findings than one asserting a universal rule.
