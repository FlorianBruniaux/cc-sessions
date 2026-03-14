#!/bin/bash
# PreToolUse security hook — blocks destructive operations

TOOL="$1"
INPUT="$2"

if [[ "$TOOL" == "Bash" ]]; then
  if echo "$INPUT" | grep -qE "rm -rf|DROP TABLE|truncate"; then
    echo "BLOCK: Destructive command requires manual confirmation" >&2
    exit 1
  fi
fi

exit 0