# Changelog

## [1.0.0] - 2026-03-13

### Added

- Initial release
- `search` — full-text search across session context with `--since`, `--branch`, `--limit` filters
- `recent` — show N most recent sessions
- `info` — display session details (date, project, branch, context)
- `resume` — resume a session by partial ID via `claude --resume`
- `reindex` — force full index rebuild
- `discover` — n-gram pattern analysis to suggest skills, commands, and CLAUDE.md rules
- `discover --llm` — semantic analysis via `claude --print` (uses existing subscription)
- Incremental JSONL index (~200ms search on 1300+ sessions)
- Git worktree support (auto-includes worktree sessions)
- `--all` flag to search across all projects
- `--json` flag for machine-readable output
- Discover cache for incremental re-analysis
- Zero dependencies (Python stdlib only)