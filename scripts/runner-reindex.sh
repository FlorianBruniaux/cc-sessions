#!/bin/bash
# runner-reindex.sh
# Measures cold reindex throughput (Boucle A)
# Usage: bash scripts/runner-reindex.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
INDEX_PATH="$HOME/.claude/sessions-index.jsonl"

# Cold start: remove existing index
rm -f "$INDEX_PATH"

BEFORE=$(python3 -c "import time; print(time.time())")
python3 "$PROJECT_DIR/cc-sessions" reindex 2>/dev/null
AFTER=$(python3 -c "import time; print(time.time())")
DURATION=$(python3 -c "print(round($AFTER - $BEFORE, 3))")

# Non-regression: index must have at least 10 entries
if [ ! -f "$INDEX_PATH" ]; then
    echo "REGRESSION: index file not created"
    exit 1
fi

COUNT=$(wc -l < "$INDEX_PATH" | tr -d ' ')
if [ "$COUNT" -lt 10 ]; then
    echo "REGRESSION: index only has $COUNT entries (expected >= 10)"
    exit 1
fi

echo "METRIC: ${DURATION}s (${COUNT} sessions indexed)"
