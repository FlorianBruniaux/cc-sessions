#!/bin/bash
# runner-discover.sh
# Measures discover command speed on last 30 days (Boucle B)
# Usage: bash scripts/runner-discover.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DISCOVER_CACHE="$HOME/.claude/discover-cache.jsonl"

# Cold start: remove discover cache to force full recompute
rm -f "$DISCOVER_CACHE"

BEFORE=$(python3 -c "import time; print(time.time())")
OUTPUT=$(python3 "$PROJECT_DIR/cc-sessions" --all discover --since 30d --min-count 2 2>/dev/null)
AFTER=$(python3 -c "import time; print(time.time())")
DURATION=$(python3 -c "print(round($AFTER - $BEFORE, 3))")

# Non-regression: must produce at least a few patterns
# Patterns appear as indented lines (starting with spaces)
PATTERN_COUNT=$(echo "$OUTPUT" | grep -c "^  " || true)
if [ "$PATTERN_COUNT" -lt 3 ]; then
    echo "REGRESSION: only $PATTERN_COUNT patterns found (expected >= 3)"
    echo "--- Output ---"
    echo "$OUTPUT"
    exit 1
fi

echo "METRIC: ${DURATION}s (${PATTERN_COUNT} patterns)"
