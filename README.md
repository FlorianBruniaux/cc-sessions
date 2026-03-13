# cc-sessions

Fast CLI to search, browse and analyze Claude Code session history.

Claude Code stores all conversation history locally in `~/.claude/projects/` as JSONL files. `cc-sessions` indexes those files for fast search and provides a clean interface to find, browse, and resume past sessions — plus a `discover` subcommand that analyzes recurring patterns to suggest what to extract as skills, commands, or CLAUDE.md rules.

## Install

```bash
curl -sL https://raw.githubusercontent.com/FlorianBruniaux/cc-sessions/main/cc-sessions \
  -o ~/.local/bin/cc-sessions && chmod +x ~/.local/bin/cc-sessions
```

Make sure `~/.local/bin` is in your `PATH`. On first run, the index builds in ~10s for 1500 sessions. Subsequent searches take under 200ms.

## Quick start

```bash
# Find all sessions mentioning "prisma"
cc-sessions search "prisma"

# Show 10 most recent sessions across all projects
cc-sessions --all recent 10

# Resume a session by partial ID
cc-sessions resume 8d472d
```

## Commands

| Command | Description |
|---------|-------------|
| `search <keyword>` | Full-text search across session context |
| `recent [N]` | Show N most recent sessions (default: 10) |
| `info <id>` | Display session details |
| `resume <id>` | Resume session via `claude --resume` (partial ID supported) |
| `reindex` | Force full index rebuild |
| `discover` | Analyze patterns, suggest skills/commands/rules |

**Global flags**: `--all` (all projects), `--json` (JSON output for piping)

### search

```bash
# Current project only
cc-sessions search "notion"

# All projects
cc-sessions --all search "stripe"

# With filters
cc-sessions search "auth" --since 7d --branch develop --limit 5
```

Flags: `--since <duration>` (e.g. `7d`, `30d`, or ISO date), `--branch <name>`, `--limit N`

### recent

```bash
cc-sessions recent 10
cc-sessions --all recent 20
cc-sessions --json recent 5 | jq -r '.[].id'
```

### resume

```bash
# Partial ID works — no need to copy the full UUID
cc-sessions resume 8d472d
```

Resolves the partial ID to the full UUID and execs `claude --resume <full-id>`.

### discover

```bash
# Analyze sessions from the last 90 days (all projects)
cc-sessions --all discover

# Narrower window, lower threshold
cc-sessions --all discover --since 60d --min-count 2 --top 15

# Semantic analysis via claude --print (uses your subscription)
cc-sessions --all discover --llm

# JSON output for scripting
cc-sessions --all discover --json | jq '.[] | select(.category == "skill")'
```

## Discover mode

`discover` reads your session history and surfaces recurring patterns — things you ask Claude to do over and over. It then suggests whether each pattern belongs in a `CLAUDE.md` rule, a skill, or a command.

### Two modes

**N-gram mode** (default, local, instant):

Tokenizes all user messages, builds a frequency index of 3-6 word phrases, clusters near-duplicates, and ranks by session coverage. No LLM call, no API key, no cost.

**LLM mode** (`--llm`):

Deduplicates messages using Jaccard similarity, sends a batch of 60 representative messages to `claude --print`, and gets back structured suggestions with rationale and suggested content. Uses your existing Claude Code subscription.

### Example output

```
  cc-sessions discover — 847 sessions · 12 project(s) · since 90d

  📋  CLAUDE.md RULE
  ────────────────────────────────────────────────────────────
  write tests before implementation
    234 sessions (28%) · 891 occurrences · score 0.416
    → 3a72f1c4-...
    → b8e290d1-...

  🧩  SKILL
  ────────────────────────────────────────────────────────────
  security review authentication flow
    71 sessions (8%) · 203 occurrences · score 0.084
    → 9f1c3a22-...

  ⚡  COMMAND
  ────────────────────────────────────────────────────────────
  generate prisma migration rollback script
    18 sessions (2%) · 44 occurrences · score 0.021
    → 44aab71c-...
```

### The 20% rule

The categorization threshold is built into the scoring:

- **> 20% of sessions** → `CLAUDE.md rule` — always load it, the overhead is worth it
- **5–20% of sessions** → `skill` — load on demand to save tokens
- **< 5% of sessions** → `command` — explicit invocation makes sense

## Performance

| Operation | Time |
|-----------|------|
| First run (build index, 1500 sessions) | ~10s |
| Subsequent search | ~200ms |
| Incremental rebuild (no changes) | <1s |
| discover scan (90d, 12 projects) | ~3s |

**Index**: `~/.claude/sessions-index.jsonl` (~280 bytes/session). Discover uses a separate `~/.claude/discover-cache.jsonl` to avoid re-reading unchanged files.

## Related tools

- [claude-history](https://github.com/...) (Rust) — fuzzy search with fzf
- [cclog](https://github.com/...) (Go) — JSONL → HTML/Markdown + TUI
- [fast-resume](https://github.com/...) (Rust) — Tantivy index + TUI

`cc-sessions` positioning: Unix-style CLI, powerful filters, zero dependencies (Python stdlib only).

## Requirements

- Python 3.8+
- Claude Code installed (for `resume` and `discover --llm`)

## License

MIT