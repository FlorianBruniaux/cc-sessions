#!/bin/bash
# runner-yield.sh
# Measures parse yield: sessions with context / total JSONL files (Boucle C)
# Usage: bash scripts/runner-yield.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
INDEX_PATH="$HOME/.claude/sessions-index.jsonl"

# Fresh reindex
rm -f "$INDEX_PATH"
python3 "$PROJECT_DIR/cc-sessions" reindex 2>/dev/null

if [ ! -f "$INDEX_PATH" ]; then
    echo "REGRESSION: index file not created"
    exit 1
fi

INDEXED=$(wc -l < "$INDEX_PATH" | tr -d ' ')

# Count JSONL files excluding agent-* sessions
TOTAL=$(find ~/.claude/projects -name "*.jsonl" ! -name "agent-*" 2>/dev/null | wc -l | tr -d ' ')

# Count sessions where context is non-empty (field "context" has at least one char after the quote)
WITH_CONTEXT=$(grep -c '"context": "[^"]' "$INDEX_PATH" || true)

if [ "$TOTAL" -eq 0 ]; then
    echo "REGRESSION: no JSONL files found in ~/.claude/projects"
    exit 1
fi

YIELD=$(python3 -c "print(round($WITH_CONTEXT / max($TOTAL, 1) * 100, 1))")
echo "METRIC: ${YIELD}% yield (${WITH_CONTEXT}/${TOTAL} sessions with context, ${INDEXED} indexed)"
