# tidy-first

An agent skill that separates **structural** changes from **behavioral** changes in a diff, sequences them so each ships on its own, and emits **hand-off prompts** another agent can execute. It speaks the open `SKILL.md` format, so it loads into any agent that reads it — not tied to one tool.

> **This skill produces the prompts. The prompt receiver produces the change.**
> It is read-only: it analyzes, classifies, sequences, and writes hand-off packages. It never rewrites the working tree or touches git.

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

## Files

| File | Role |
|------|------|
| [`skills/tidy-first/SKILL.md`](skills/tidy-first/SKILL.md) | The 5-step process: resolve input + baseline → classify → untangle → sequence → emit packages. |
| [`skills/tidy-first/TIDIES.md`](skills/tidy-first/TIDIES.md) | The structural-change catalog (Beck's named tidyings), the green oracle, the untangle technique, and the **mapping to conventional commits**. |
| [`skills/tidy-first/HANDOFF-FORMAT.md`](skills/tidy-first/HANDOFF-FORMAT.md) | The per-step hand-off package contract (`type:` + `commit:` + scope + verification + ordering + the human's `decision:` stub) and the sequence summary table. |

## Install

With [skills.sh](https://skills.sh):

```sh
npx skills add dtun/tidy-first
```

Or place the skill folder wherever your agent loads skills from — a skill is just a directory containing `SKILL.md`:

```sh
git clone https://github.com/dtun/tidy-first.git
ln -s "$PWD/tidy-first/skills/tidy-first" ~/.agents/skills/tidy-first
```

Then invoke with `/tidy-first <PR url/number | file | dir>`.

## Inputs

A **PR/branch** (the diff is explicit), or a **file/dir** (the skill picks and states an implied baseline — working tree vs `HEAD`, or branch vs `main`).

## What the human decides

The skill never decides refactor-first / refactor-last / don't-refactor. It lays the sequence out with a recommendation and leaves the `decision:` field on each `refactor:` step for you to set.

## Credit

The structural/behavioral lens, the "tidy first?" framing (the question mark is load-bearing), and the named tidyings all come from Kent Beck's [_Tidy First?_](https://www.oreilly.com/library/view/tidy-first/9781098151232/) (O'Reilly, 2023). This skill applies his ideas — it's no substitute for the book.

## License

[MIT](LICENSE) © 2026 Danny Tunney
