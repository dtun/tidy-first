# AGENTS.md

Guidance for any agent working in this repository.

## What this repo is

A single agent skill, `tidy-first`, distributed in the open `SKILL.md` format. It is
**agent-neutral** — it should read and run the same in any agent, not just one tool.

- The skill lives in [`skills/tidy-first/`](skills/tidy-first/). `SKILL.md` is the entry
  point; `TIDIES.md` and `HANDOFF-FORMAT.md` are references it links to relatively.
- Version and author live in the `SKILL.md` frontmatter (`metadata.version`). Keep that in
  sync with [`CHANGELOG.md`](CHANGELOG.md) and the git tag on release.

## Conventions

- **Keep it agent-neutral.** Don't hard-code one agent's tool names (e.g. a specific
  subagent or tool). Describe capabilities generically ("a search/exploration subagent",
  "a fresh subagent or a separate session").
- **The skill is read-only.** It analyzes, classifies, sequences, and writes hand-off
  packages to a temp dir. It never edits the working tree or touches git. Preserve that.
- **Work in [Conventional Commits](https://www.conventionalcommits.org/)** — discrete,
  well-scoped commits. Don't force-push or amend without asking.
