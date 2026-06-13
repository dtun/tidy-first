# Changelog

All notable changes to this skill are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
The released version is mirrored in the `metadata.version` field of
[`skills/tidy-first/SKILL.md`](skills/tidy-first/SKILL.md).

## [Unreleased]

## [0.1.0] — 2026-06-12

Initial release.

### Added

- `tidy-first` skill: classify every hunk in a diff as structural (a tidy) or
  behavioral, untangle mixed hunks into green intermediate states, sequence the
  steps, and emit one hand-off package per step for a receiving agent to execute.
  Agent-neutral and read-only — it produces the prompts, never the change.
- The **green oracle** classification rule with strong (suite-runnable) and
  heuristic (`unverified`) tiers.
- [`TIDIES.md`](skills/tidy-first/TIDIES.md) — the structural-change catalog
  (Kent Beck's named tidyings) and the mapping from the structure/behavior lens
  to Conventional Commit types.
- [`HANDOFF-FORMAT.md`](skills/tidy-first/HANDOFF-FORMAT.md) — the per-step
  hand-off package contract and sequence summary table.

[Unreleased]: https://github.com/dtun/tidy-first/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/dtun/tidy-first/releases/tag/v0.1.0
