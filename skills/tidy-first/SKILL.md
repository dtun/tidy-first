---
name: tidy-first
description: Separate structural changes (tidies) from behavioral changes in a diff, sequence them so each ships on its own, and generate hand-off prompts another agent can execute. Use when a PR/branch/file/dir mixes refactoring with new behavior, when the user wants to "tidy first," split a fat diff into reviewable steps, untangle a messy change, or hand the boring refactor to another agent so their PR is just the behavior.
argument-hint: "<PR url/number | file | dir>"
license: MIT
metadata:
  author: Danny Tunney
  version: "0.1.0"
---

# Tidy First

Take a tangled change and split it into **tidies** (structural, behavior-preserving) and **behavioral** changes, then emit a **sequence of hand-off prompts** — one per step — that a *receiving* agent executes.

**This skill produces the prompts. The prompt receiver produces the change.** This skill is read-only: it analyzes, classifies, sequences, and writes hand-off packages. It never rewrites the working tree or touches git. The doing is delegated.

**Think in structure/behavior; ship in conventional commits.** "Tidy," "structural," and "behavioral" are the *diagnostic lens* — use them while reasoning and in the opening discussion with the user. But the team doesn't ship "tidies"; it ships `feat:` and `refactor:`. So **every artifact this skill emits — the plan, the hand-off packages, the proposed commit messages, the PR titles — must speak conventional commits, not the lens.** A confirmed tidy is written up as a `refactor:`; a behavioral change as a `feat:` or `fix:`. Never put the word "tidy" in a plan row, a package, or a commit. See the mapping in [TIDIES.md](TIDIES.md#translating-to-conventional-commits).

The question mark in Beck's _Tidy First?_ is load-bearing. This skill does **not** decide tidy-first vs tidy-last vs don't-tidy — it lays the options out with their consequences and a recommendation, and **the human chooses**. Every step it emits carries a `decision:` field the human sets.

## Glossary

Use these terms exactly. Full catalog and detection rules in [TIDIES.md](TIDIES.md).

- **Tidy** — a small, safe, reversible structural change: extract, inline, rename, move, reorder, normalize. By definition it preserves observable behavior. Named after Kent Beck's _Tidy First?_. **Ships as `refactor:`** (or `style:`/`test:`/`docs:` for the narrow cases — see [TIDIES.md](TIDIES.md#translating-to-conventional-commits)).
- **Behavioral change** — anything that alters observable behavior: new logic, changed output, a fixed bug, a new branch. Comes with test changes. **Ships as `feat:`** (new capability) **or `fix:`** (corrected behavior).
- **The green oracle** — the test suite is the definition of "observable behavior." A change is a tidy **iff the existing tests pass, unchanged, before and after it.** The moment a hunk requires a test to change or makes one fail, it is behavioral.
- **Untangle** — splitting a single hunk that contains *both* a tidy and a behavioral change into an ordered pair of states, each one green-or-honestly-flagged.
- **Hand-off package** — the executable prompt for one step: scope, transform, verification, ordering, and the human's `decision:` stub. The unit this skill emits. Format in [HANDOFF-FORMAT.md](HANDOFF-FORMAT.md).
- **Strong oracle / heuristic oracle** — strong = you can build and run the suite, so tidy-ness is *proven*. Heuristic = you can't (foreign PR, no env, flaky/slow suite), so tidy-ness is *inferred* and **must be flagged as unverified**.

Key principles:

- **Structure-first is the default, not a law.** Tidies usually go first because they make the behavioral change small and obvious — but a tidy that only becomes *safe* after a behavioral fix must wait. Sequence by dependency, not dogma.
- **The untangle is the explanation.** Once the rename is pulled out, the 4 lines of logic hiding inside it become the whole point — review sees the behavior, not the noise.
- **Reversibility is the safety net.** A tidy shipped as its own green commit can be reverted with zero behavior lost. That is what makes "tidy first?" a cheap bet rather than a commitment.
- **Never claim certainty you don't have.** A heuristic-tier guess labeled as proven is worse than no skill at all.

## Process

### 1. Resolve the input and its baseline

You need *two states to diff* — a file or a dir on its own is just code, not a change. Establish the baseline:

- **PR / branch** — the change is explicit: base branch → head. Use it directly (`gh pr diff`, or diff against the merge base).
- **File / dir** — pick an implied baseline and state it out loud: working tree vs `HEAD`, or this branch vs `main`, scoped to that path. If there is no diff, say so and stop.

Decide the **oracle tier** now and tell the user which you're in:

- Can you build and run the test suite here? → **strong oracle**.
- Foreign PR, no environment, or a suite too slow/flaky to run per-step? → **heuristic oracle**. Everything you emit gets an `unverified` flag.

### 2. Classify every hunk

Use a search/exploration subagent to walk the diff. For each hunk, label it `tidy`, `behavioral`, or `mixed`, following [TIDIES.md](TIDIES.md). (This labelling is internal — the lens. You'll translate to conventional-commit types in step 5.)

1. **Cheap AST pre-pass first.** Pure renames, moves, reorders, extractions, formatting → almost certainly `tidy`. New conditionals, changed return values, added/removed calls with effects → `behavioral`. This catches the obvious majority without running anything.
2. **Green oracle for the ambiguous rest** (strong tier only): construct the candidate tidy-only state, run the suite. Passes unchanged → confirmed `tidy`. Requires a test edit or fails → `behavioral` (or the tidy half of a `mixed`).
3. **Heuristic tier**: classify from diff + AST alone and mark every result `unverified`.

### 3. Untangle the mixed hunks

For each `mixed` hunk, propose the split into an ordered pair (or chain) of states. The invariant is absolute:

> **Every proposed intermediate state must itself be green** — it compiles and the existing tests pass.

In the strong tier, *materialize the intermediate and run the suite* before you trust the untangle — proposing and verifying are the same act. In the heuristic tier, propose the untangle but stamp it `unverified: intermediate not built`.

If a hunk genuinely cannot be untangled into green steps, say so plainly — don't emit a fake split.

### 4. Sequence the steps

Topologically sort all steps into a shippable order:

- Default tidies ahead of behavior, **but** honor real edges: a tidy that moves code a behavioral hunk lands in must precede it; a tidy only safe after a fix must follow it.
- Each step in the sequence should be tidy-or-behavioral, not both, and shippable on its own (its own green commit / PR).
- Note dependencies explicitly so steps can be reordered or dropped without silent breakage.

### 5. Emit the hand-off packages and let the human decide

**Translate the lens into the delivery vocabulary now.** Every step is written as a conventional commit, not as a "tidy"/"behavioral" label: tidy → `refactor:` (or `style:`/`test:`/`docs:`), behavioral → `feat:`/`fix:`. The mapping lives in [TIDIES.md](TIDIES.md#translating-to-conventional-commits).

Write one **hand-off package** per step per [HANDOFF-FORMAT.md](HANDOFF-FORMAT.md). Each is a self-contained prompt a receiving agent can execute: a `type:` (the conventional-commit type), a proposed **commit message** in that type, **scope** (files/hunks), **transform** (named with the precise structural move, e.g. "extract method `foo`", for refactors), **verification** (the exact command that proves green), **ordering** (position + deps), and the **`decision:` stub** (`refactor-first | refactor-last | skip`) — pre-filled with your recommendation, left for the human to set.

Present the sequence as a summary table keyed by conventional-commit type, lead with your recommended path and *why* (e.g. "land the two `refactor:` steps on `main` first → your `feat:` PR becomes the 12-line behavior change against clean code; revert the extraction alone if it proves wrong"), then hand control back:

> "Here's the proposed sequence. Set `decision:` on the `refactor:` steps, or tell me to hand them off as-is."

Only when the human approves does a step's package go to a receiving agent (a fresh subagent, or copied into another session). This skill stops at the prompt.
