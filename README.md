# tidy-first

Home to **two sibling agent skills** that keep structural change and behavioral change apart — one on the way *in*, one looking *back*. Both speak the open `SKILL.md` format, so they load into any agent that reads them — not tied to one tool.

- **`tidy-first`** — separates structural from behavioral changes in *one pending diff*, sequences them so each ships on its own, and emits **hand-off prompts** another agent can execute.
- **`tidy-audit`** — scans *a window of already-shipped commits* and reports a ranked `refactor:` cleanup **backlog**: the "shall we tidy _last_?" pass, applied retrospectively.

> Both are **read-only.** `tidy-first` produces prompts; `tidy-audit` produces a report. Neither rewrites the working tree or touches git — the doing is always delegated.

## The idea

Every fat diff mixes two kinds of change:

- **Structural** — extract, inline, rename, move, reorder, normalize. Preserves observable behavior. (Kent Beck's _Tidy First?_ vocabulary.)
- **Behavioral** — new logic, changed output, a fixed bug. Alters what the system does.

Separating them makes review cheap (a pure structural change is rubber-stampable; the behavioral diff gets the real attention), makes `git bisect`/revert clean, and surfaces intent — once the rename is pulled out, the few lines of logic hiding inside it become the whole point.

## Two vocabularies

- **The lens** (structure/behavior, "tidy") is *diagnostic* — used while reasoning and in the opening discussion.
- **The delivery vocabulary** (`feat:`, `fix:`, `refactor:`, …) is what every emitted artifact speaks — plans, hand-off packages, commit messages, PR titles. Nobody ships a "tidy"; they ship a `refactor:`.

The skill **thinks in structure/behavior and ships in conventional commits.**

## How it classifies — the green oracle

> A change is structural (a `refactor:`) **iff the existing tests pass, unchanged, before and after it.** The moment a hunk requires a test to change, it's behavioral (`feat:`/`fix:`).

Two tiers of confidence:

- **Strong oracle** — you can build and run the suite, so structural-ness is *proven*.
- **Heuristic oracle** — you can't (foreign PR, no env, flaky suite), so it's *inferred* and flagged `unverified`. A guess is never labeled as proven.

## `tidy-audit` — the retrospective pass

Where `tidy-first` works one pending change, `tidy-audit` looks back over a **range of shipped commits** and asks _"what did this run leave messy — what should we clean next?"_ It emits a ranked cleanup **backlog** (new work), not a rewrite of history. It's a sibling of `/code-review`, not a mode of `tidy-first`.

| | `tidy-first` | `tidy-audit` |
|---|---|---|
| Operates on | one pending change (PR/branch/tree) | a range of shipped commits |
| Question | "how do I split & ship this cleanly?" | "what did this leave messy — clean next?" |
| Produces | hand-off packages that *reproduce the change* | a ranked cleanup **backlog** |
| Actionable on its input? | yes — you ship it | no — shipped history is frozen |

It **reuses** `TIDIES.md` (the structural moves are the fixes it proposes) and adds [`ANTIPATTERNS.md`](skills/tidy-audit/ANTIPATTERNS.md) — the debt *smells* you can only see over a window of history (tangled commits, churn, cross-author duplication, growth). It first scans the target repo's **own** conventions (docs + observed patterns) so findings are judged against what's canonical *there*, not an assumed rule. Every finding carries `confidence` + `basis`; it never claims proven. Input is a GitHub commits URL, a local range, or an `owner/repo` + range — all resolved read-only.

## Files

| File | Role |
|------|------|
| [`skills/tidy-first/SKILL.md`](skills/tidy-first/SKILL.md) | The 5-step process: resolve input + baseline → classify → untangle → sequence → emit packages. |
| [`skills/tidy-first/TIDIES.md`](skills/tidy-first/TIDIES.md) | The structural-change catalog (Beck's named tidyings), the green oracle, the untangle technique, and the **mapping to conventional commits**. |
| [`skills/tidy-first/HANDOFF-FORMAT.md`](skills/tidy-first/HANDOFF-FORMAT.md) | The per-step hand-off package contract (`type:` + `commit:` + scope + verification + ordering + the human's `decision:` stub) and the sequence summary table. |
| [`skills/tidy-audit/SKILL.md`](skills/tidy-audit/SKILL.md) | The audit process: resolve window + baseline → scan codebase conventions → gather signal → detect against both catalogs → cluster → rank → emit report. |
| [`skills/tidy-audit/ANTIPATTERNS.md`](skills/tidy-audit/ANTIPATTERNS.md) | The debt-detector catalog (§7 seed set), each tagged *absolute* or *codebase-relative*, with its resolving `refactor:`. Extensible. |
| [`skills/tidy-audit/AUDIT-FORMAT.md`](skills/tidy-audit/AUDIT-FORMAT.md) | The single-report format: entropy delta, ranked table, per-opportunity block, and the **actionable vs observations** split. |
| [`skills/tidy-audit/TIDIES.md`](skills/tidy-audit/TIDIES.md) | A copy of `tidy-first`'s catalog, so `tidy-audit` installs standalone. Kept in sync with the original. |

## Install

With [skills.sh](https://skills.sh):

```sh
npx skills add dtun/tidy-first    # or: dtun/tidy-audit
```

Or place a skill folder wherever your agent loads skills from — a skill is just a directory containing `SKILL.md`:

```sh
git clone https://github.com/dtun/tidy-first.git
ln -s "$PWD/tidy-first/skills/tidy-first" ~/.agents/skills/tidy-first
ln -s "$PWD/tidy-first/skills/tidy-audit" ~/.agents/skills/tidy-audit
```

Then invoke:

- `/tidy-first <PR url/number | file | dir>`
- `/tidy-audit <github-commits-url | since [until]> [--path <glob>] [--author <name>] [--top <N>]`

## Inputs

A **PR/branch** (the diff is explicit), or a **file/dir** (the skill picks and states an implied baseline — working tree vs `HEAD`, or branch vs `main`).

## What the human decides

The skill never decides refactor-first / refactor-last / don't-refactor. It lays the sequence out with a recommendation and leaves the `decision:` field on each `refactor:` step for you to set.

## Credit

The structural/behavioral lens, the "tidy first?" framing (the question mark is load-bearing), and the named tidyings all come from Kent Beck's [_Tidy First?_](https://www.oreilly.com/library/view/tidy-first/9781098151232/) (O'Reilly, 2023). This skill applies his ideas — it's no substitute for the book.

## License

[MIT](LICENSE) © 2026 Danny Tunney
