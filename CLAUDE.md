# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

`cc-sessions` is a single-file Python CLI (`cc-sessions`) that indexes and searches Claude Code session history from `~/.claude/projects/`. Zero dependencies — Python stdlib only.

## Common Commands

```bash
# Run the CLI (from project root or after install)
python3 cc-sessions <command>

# Run a specific command during development
python3 cc-sessions search "keyword"
python3 cc-sessions --all recent 10
python3 cc-sessions discover --since 30d

# Force index rebuild (useful when testing parsing changes)
python3 cc-sessions reindex

# Install locally for live testing
cp cc-sessions ~/.local/bin/cc-sessions && chmod +x ~/.local/bin/cc-sessions
```

No build step, no test suite, no dependencies to install.

## Architecture

Everything lives in a single executable script: `cc-sessions`.

**Index system** (`~/.claude/sessions-index.jsonl`):
- Incremental JSONL index, ~280 bytes/session
- Built/updated automatically on `search` and `recent`; forced via `reindex`
- `build_index()` skips sessions whose `mtime` hasn't changed (incremental)
- Subagent sessions (prefix `agent-`) are excluded

**Session filtering rules** (applied in `get_first_user_message` and `extract_all_user_messages`):
1. `entry['type'] == 'user'`
2. `content` is a string (not array — tool results are arrays)
3. Content doesn't start with `<` (excludes all XML-formatted system messages)
4. Length 10–800 chars (excludes acks and compact summaries)
5. `_is_system_injection()` check against known boilerplate markers

**Discover subcommand** has two modes:
- **N-gram mode** (default): tokenizes user messages, builds 3-6 word phrase frequency index, clusters near-duplicates with Jaccard similarity, ranks by session coverage
- **LLM mode** (`--llm`): deduplicates messages, sends batches of 60 to `claude --print`, gets structured suggestions back
- Uses separate cache `~/.claude/discover-cache.jsonl` to avoid re-reading unchanged files

**Categorization thresholds**:
- >20% of sessions → `CLAUDE.md rule`
- 5–20% → `skill`
- <5% → `command`

**Project detection**: encodes `cwd` to match Claude's path encoding (`/` → `-`), then looks for `~/.claude/projects/<encoded-path>/`. Worktrees are auto-included via glob `<project>--worktrees*`.

## Key Functions

| Function | Purpose |
|---|---|
| `parse_session()` | Extract metadata from one JSONL file |
| `build_index()` | Incremental index build across project dirs |
| `cmd_search/recent/info/resume/reindex/discover` | One function per subcommand |
| `normalize_text()` | Tokenize + stop-word filter for n-gram analysis |
| `_is_system_injection()` | Filter Claude-injected messages from discover corpus |
| `call_claude_llm()` | Batch LLM call via `claude --print` for `--llm` mode |

## Examples

```bash
# Force reindex + search combo (useful after parsing changes)
python3 cc-sessions reindex && python3 cc-sessions search "auth"

# Discover patterns across all projects, last 30 days
python3 cc-sessions --all discover --since 30d --min-count 3

# Export JSON for scripting
python3 cc-sessions --all --json recent 20 | jq '.[].project' | sort | uniq -c
```

## Conventions

- Single file, stdlib only — no external imports ever
- Test locally: `cp cc-sessions ~/.local/bin/ && cc-sessions <cmd>` (or `/install-local`)
- Filtering logic lives in `_is_system_injection()` and `get_first_user_message()` — touch carefully
- Index at `~/.claude/sessions-index.jsonl`, discover cache at `~/.claude/discover-cache.jsonl`