# AGENTS.md

Guidance for any agent working in this repository.

## What this repo is

**Two sibling agent skills**, `tidy-first` and `tidy-audit`, distributed in the open
`SKILL.md` format. Both are **agent-neutral** — they should read and run the same in any
agent, not just one tool.

- `tidy-first` lives in [`skills/tidy-first/`](skills/tidy-first/) (`SKILL.md` + `TIDIES.md`
  + `HANDOFF-FORMAT.md`). It splits *one pending change* and emits hand-off prompts.
- `tidy-audit` lives in [`skills/tidy-audit/`](skills/tidy-audit/) (`SKILL.md` +
  `ANTIPATTERNS.md` + `AUDIT-FORMAT.md` + a copy of `TIDIES.md`). It audits *a range of
  shipped commits* and emits a ranked cleanup report. Sibling of `/code-review`, not a mode
  of `tidy-first`.
- Each skill's `SKILL.md` is its own entry point; sibling files are references it links to
  relatively. Version and author live in each `SKILL.md` frontmatter (`metadata.version`).
- The repo root doubles as a **Claude Code plugin and its marketplace**:
  [`.claude-plugin/plugin.json`](.claude-plugin/plugin.json) declares the `tidy` plugin
  (`"skills": "./skills/"`, so both skills ship together) and
  [`.claude-plugin/marketplace.json`](.claude-plugin/marketplace.json) lists it with
  `"source": "./"`. That's why `skills/*` must stay at the repo root — moving it breaks
  plugin discovery, skills.sh, and every README link at once.

## Conventions

- **Keep them agent-neutral.** Don't hard-code one agent's tool names (e.g. a specific
  subagent or tool). Describe capabilities generically ("a search/exploration subagent",
  "the GitHub CLI or API", "a fresh subagent or a separate session").
- **Both skills are read-only.** They analyze and emit artifacts to a temp dir (prompts /
  a report). Neither edits the working tree, writes to a target repo, or touches git.
  `tidy-audit` may make a *throwaway read-only clone* in the temp dir — never a write or
  push. Preserve that.
- **`TIDIES.md` exists in two copies** — [`skills/tidy-first/TIDIES.md`](skills/tidy-first/TIDIES.md)
  and [`skills/tidy-audit/TIDIES.md`](skills/tidy-audit/TIDIES.md) — so each skill installs
  standalone. They are meant to be **byte-identical**; when you change one, change the other
  (verify with `diff`).
- **Work in [Conventional Commits](https://www.conventionalcommits.org/)** — discrete,
  well-scoped commits. Don't force-push or amend without asking.

## Releasing

One version number, declared in three files that must agree:

1. `metadata.version` in [`skills/tidy-first/SKILL.md`](skills/tidy-first/SKILL.md)
2. `metadata.version` in [`skills/tidy-audit/SKILL.md`](skills/tidy-audit/SKILL.md)
3. `version` in [`.claude-plugin/plugin.json`](.claude-plugin/plugin.json) — Claude Code
   only ships an update when this string changes, so a forgotten bump leaves users stale

Then move the [`CHANGELOG.md`](CHANGELOG.md) `Unreleased` heading to `X.Y.Z`, update its
compare links, and tag `vX.Y.Z`. Validate the manifests with `claude plugin validate .`
