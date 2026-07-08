# Tidies — catalog and classification

A **tidy** is a small, safe, reversible structural change that preserves observable behavior. The catalog below is drawn from Kent Beck's _Tidy First?_. Name tidies using this vocabulary in every hand-off package — consistent language is how the receiving agent knows exactly what to do.

## The green oracle (the one rule)

The test suite **is** the definition of observable behavior. Therefore:

> A change is a **tidy** if and only if the existing tests pass, **unchanged**, both before and after it.

- Tests pass unchanged → structural → **tidy**.
- A test had to change, or a test goes red → behavior moved → **behavioral**.

Everything else in this file is a cheap way to *guess* the oracle's answer without paying to run it. When the guess and the oracle disagree, the oracle wins.

## Tidy catalog (structural — should be green unchanged)

Beck's named tidyings from _Tidy First?_. Use the exact name in the package's `transform:` field — the name **is** the instruction to the receiver.

- **Guard Clauses** — replace nested conditionals with early returns for special cases, so the main path reads flat.
- **Dead Code** — delete code that is never reached or never used.
- **Normalize Symmetries** — make code that does the same thing look the same way (one idiom for one job throughout).
- **New Interface, Old Implementation** — add a cleaner interface that simply forwards to the existing one; callers can migrate later.
- **Reading Order** — reorder elements in a file so a reader meets them in the order they want to understand them.
- **Cohesion Order** — move coupled elements adjacent to each other so related changes stay local.
- **Move Declaration and Initialization Together** — relocate a variable's declaration down to where it's first given a meaningful value.
- **Explaining Variable** — extract a sub-expression into a named variable that states its intent.
- **Explaining Constant** — replace a magic literal with a named constant.
- **Explicit Parameters** — pass what a routine needs as explicit parameters instead of reaching into a map/blob/global.
- **Chunk Statements** — insert a blank line to separate a block of statements into a coherent chunk.
- **Extract Helper** — pull a cohesive fragment into a named helper with a clear interface.
- **One Pile** — temporarily inline scattered fragments into one place so you can see the whole, before re-splitting well.
- **Explaining Comments** — add a comment that records something non-obvious the code can't say itself.
- **Delete Redundant Comments** — remove comments that only restate what the code already says.

General behavior-preserving refactorings also count as tidies when the green oracle confirms them — **Rename**, **Move**, **Inline**, **Reorder** (declarations/params/independent statements). Use these names when none of Beck's tidyings fit precisely.

## Behavioral signals (NOT tidies)

- A new or changed conditional / branch.
- A changed return value, output, side effect, or call argument that matters.
- An added or removed call to something with effects (I/O, mutation, network).
- A bug fix — even a one-character one.
- Anything that *requires* a test to be added, edited, or deleted to stay green.

## Translating to conventional commits

The structure/behavior lens is for *classifying*. The team ships *conventional commits*. Translate before anything is written into a plan, package, commit, or PR — and never let the words "tidy" or "behavioral" appear in those artifacts.

| classification (the lens) | ships as | when |
|---|---|---|
| tidy — Extract/Inline/Rename/Move/Reorder, Guard Clauses, Cohesion Order, Reading Order, Normalize Symmetries, Explaining Var/Const, Explicit Parameters, Chunk Statements, Extract Helper, One Pile, Dead Code | **`refactor:`** | the default for a structural change |
| tidy — formatting / whitespace only | **`style:`** | no code-meaning change at all |
| tidy — test-harness only (add a mock, a helper, a fixture) | **`test:`** | only test scaffolding moved |
| tidy — Explaining Comments / Delete Redundant Comments only | **`docs:`** | comment-only |
| behavioral — new capability | **`feat:`** | adds something observable |
| behavioral — corrected wrong behavior | **`fix:`** | a bug is being fixed |
| behavioral — build/deps/config/codegen | **`chore:`** | no app behavior, but not structural either |

Rules of thumb:

- **Most tidies are `refactor:`.** Reach for `style:`/`test:`/`docs:` only when the change is *purely* that narrow thing.
- The commit message body still names the precise structural move ("extract method `validateCart`") — that precision is what the receiver executes. The *type* is conventional; the *description* is specific.
- An untangled `mixed` hunk becomes a `refactor:` commit followed by a `feat:`/`fix:` commit — the two types are the visible proof the concern was split.

## AST pre-pass vs the oracle

1. **AST pre-pass (cheap, always available).** Match the hunk against the catalog. Pure shape-changes → label `tidy`. Behavioral signals → label `behavioral`. This resolves the obvious majority for free.
2. **Green oracle (strong tier only).** For hunks the pre-pass can't call confidently, materialize the candidate tidy-only state and run the suite. The result is *proof*, not a guess.
3. **Heuristic tier (no runnable suite).** Use the AST pre-pass alone and stamp every result `unverified`. Be conservative: when a hunk could be behavioral, call it behavioral. A false `tidy` is the dangerous error — it tells a reviewer "nothing to see here" when there is.

## Untangling a `mixed` hunk

A hunk is `mixed` when a tidy and a behavioral change touch the same lines (e.g. a rename *and* a logic tweak on one line).

Propose an **ordered chain of states**, each green:

1. **Tidy-only intermediate** — apply just the structural part (the rename), leave the logic as it was. Existing tests pass unchanged.
2. **Behavioral step** — apply the logic change on top. Now the diff is *only* the behavior — that isolated diff is the explanation of what's being unlocked.

The invariant: **every intermediate must compile and pass the existing tests.** In the strong tier, build the intermediate and run the suite to prove it — proposing the untangle and verifying it are the same act. In the heuristic tier, propose it but flag `unverified: intermediate not built`.

If no green intermediate exists (the tidy and the behavior are truly inseparable), say so — emit a single `behavioral` step and note why it couldn't be untangled. Never fabricate a split that wouldn't actually be green; a false untangle makes review *harder*, not easier.
