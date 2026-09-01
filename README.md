# cc-sessions

<table>
  <tr>
    <td width="64">
      <a href="https://www.florian.bruniaux.com/about/?utm_source=github&amp;utm_medium=readme&amp;utm_campaign=cc-sessions"><img src="https://cc.bruniaux.com/author.png" width="56" height="56" alt="Florian Bruniaux" /></a>
    </td>
    <td>
      <strong><a href="https://www.florian.bruniaux.com/about/?utm_source=github&amp;utm_medium=readme&amp;utm_campaign=cc-sessions">Florian BRUNIAUX</a></strong> &middot; AI Founding Engineer @ <a href="https://methode-aristote.fr/">Méthode Aristote</a><br />
      13 years from developer to CTO / VP Eng &middot; <a href="https://www.florian.bruniaux.com/blog/?utm_source=github&amp;utm_medium=readme&amp;utm_campaign=cc-sessions">Blog &#8599;</a> &middot; <a href="https://www.florian.bruniaux.com/projects/?utm_source=github&amp;utm_medium=readme&amp;utm_campaign=cc-sessions">Projects &#8599;</a>
    </td>
  </tr>
</table>

Fast CLI to search, browse and analyze Claude Code session history.

Claude Code stores all conversation history locally in `~/.claude/projects/` as JSONL files. `cc-sessions` indexes those files for fast search and provides a clean interface to find, browse, and resume past sessions — plus a `discover` subcommand that analyzes recurring patterns to suggest what to extract as skills, commands, or CLAUDE.md rules.

## StarMapper

<a href="https://starmapper.bruniaux.com/FlorianBruniaux/cc-sessions">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://starmapper.bruniaux.com/api/map-image/FlorianBruniaux/cc-sessions?theme=dark" />
    <source media="(prefers-color-scheme: light)" srcset="https://starmapper.bruniaux.com/api/map-image/FlorianBruniaux/cc-sessions?theme=light" />
    <img alt="StarMapper — see who stars this repo on a world map" src="https://starmapper.bruniaux.com/api/map-image/FlorianBruniaux/cc-sessions" />
  </picture>
</a>

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

`cc-sessions` positioning: Unix-style CLI, powerful filters, zero dependencies (Python stdlib only).

<!-- BEGIN GENERATED RELATED PROJECTS -->
<!-- Source: https://github.com/FlorianBruniaux/FlorianBruniaux/blob/main/ecosystem/projects.json; project: cc-sessions -->
## Explore the ecosystem

These projects extend the workflow without duplicating this tool:

- **Visualize with [CCBoard](https://github.com/FlorianBruniaux/ccboard)**: switch to a complete dashboard when targeted CLI search is not enough.
- **Analyze with [cc-skill-usage](https://github.com/FlorianBruniaux/cc-skill-usage)**: inspect one specialist signal in the same local transcripts.
- **Learn with [Claude Code Ultimate Guide](https://github.com/FlorianBruniaux/claude-code-ultimate-guide)**: go deeper on sessions, memory, and context continuity.

[Browse the complete open-source galaxy](https://github.com/FlorianBruniaux#open-source-galaxy)
<!-- END GENERATED RELATED PROJECTS -->

## Autoresearch loops

The `scripts/` directory contains performance optimization runners for iterative improvement of cc-sessions internals.

### Setup

```bash
# Run a baseline measurement before making changes
bash scripts/runner-reindex.sh    # cold reindex throughput
bash scripts/runner-discover.sh   # discover speed on last 30 days
bash scripts/runner-yield.sh      # parse yield (sessions with context / total)
```

### Loop A — Reindex throughput

**Target**: `parse_session()` + `build_index()` (hot path on every search/recent call)

**What it measures**: cold reindex time in seconds

**Program**: `scripts/program-reindex.md`

**Key optimization**: fuse the two file reads in `parse_session()` into one (branch + context in the same pass). Realistic gain: 30-50%.

### Loop B — Discover speed

**Target**: `discover_patterns()` clustering step (O(n²) Jaccard comparisons)

**What it measures**: `discover --since 30d` wall time in seconds

**Program**: `scripts/program-discover.md`

**Key optimization**: replace O(n²) Jaccard clustering with sorted-token bucketing. Realistic gain: 50-80%.

### Loop C — Parse yield

**Target**: `get_first_user_message()` + `_is_system_injection()` filters

**What it measures**: % of JSONL files that produce a non-empty context in the index

**Program**: `scripts/program-yield.md`

**Key optimization**: fall back to the next user message (up to 5 candidates) when the first is filtered, and tighten overly broad injection markers. Realistic gain: 5-15% more sessions indexed.

### Running an optimization agent

```bash
# Isolated worktree to avoid polluting main branch
git worktree add ../cc-sessions-autoresearch
cd ../cc-sessions-autoresearch

# Measure baseline
bash scripts/runner-reindex.sh

# Launch agent with the program instructions
claude --dangerously-skip-permissions \
  "$(cat scripts/program-reindex.md)"

# Measure result
bash scripts/runner-reindex.sh

# Clean up if not keeping
git worktree remove ../cc-sessions-autoresearch
```

## Requirements

- Python 3.8+
- Claude Code installed (for `resume` and `discover --llm`)

## License

MIT
