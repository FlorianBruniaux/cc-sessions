# Changelog

## [1.1.0] - 2026-03-14

### Added

- `last`: resume the most recent session in the current project (or `--all` for global most recent)
- `context <id>`: preview the first N significant user messages of a session before resuming — accepts partial ID, `--messages N` flag, `--json` output
- `search --deep`: bypass the index and scan all user messages in session files; slower but finds matches anywhere in the conversation, not just the opening message
- Hint on empty `search` results: suggests `--deep` automatically

### Changed

- `cmd_info` and `cmd_resume` refactored to use shared `resolve_session_id()` helper (no behavior change)
- New `session_filepath()` helper centralizes JSONL path reconstruction

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