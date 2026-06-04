---
name: worktree-status
description: Check the status of background type check for a git worktree
model: haiku
argument-hint: "<branch-name>"
---

# Worktree Status Check

Check the status of background type check for a git worktree.

**Purpose**: Query type check results without blocking initial worktree setup.

## Usage

```bash
/worktree-status feature/auth
/worktree-status fix/session-bug
```

## Implementation

Execute this script with branch name from `$ARGUMENTS`:

```bash
#!/bin/bash
set -euo pipefail

BRANCH_NAME="$ARGUMENTS"
LOG_FILE="/tmp/worktree-typecheck-${BRANCH_NAME//\//-}.log"

# Check if log file exists
if [ ! -f "$LOG_FILE" ]; then
  echo "❌ No type check found for branch: $BRANCH_NAME"
  echo ""
  echo "Possible reasons:"
  echo "1. Worktree was created with --fast flag (type check skipped)"
  echo "2. Branch name mismatch (use exact branch name)"
  echo "3. Type check hasn't started yet (wait a few seconds)"
  echo ""
  echo "Available logs:"
  ls -1 /tmp/worktree-typecheck-*.log 2>/dev/null || echo "  (none)"
  exit 1
fi

# Read log content (limit to 1000 lines to prevent memory issues with huge logs)
LOG_CONTENT=$(head -n 1000 "$LOG_FILE")

# Check status based on log content
if echo "$LOG_CONTENT" | grep -q "✅ Type check passed"; then
  # Extract timestamp
  TIMESTAMP=$(echo "$LOG_CONTENT" | grep "Type check passed" | sed 's/.*at //')

  echo "✅ Type check passed"
  echo "   Completed at: $TIMESTAMP"
  echo ""
  echo "Worktree is ready for development!"

elif echo "$LOG_CONTENT" | grep -q "❌ Type check failed"; then
  # Extract timestamp
  TIMESTAMP=$(echo "$LOG_CONTENT" | grep "Type check failed" | sed 's/.*at //')

  echo "❌ Type check failed"
  echo "   Completed at: $TIMESTAMP"
  echo ""

  # Count total errors (including beyond 1000 line limit)
  # Use grep -c to avoid counting blank lines
  ERROR_COUNT=$(grep -v "Type check" "$LOG_FILE" | grep -c -v '^[[:space:]]*$' || echo "0")

  # Warn if extremely large log file
  if [ "$ERROR_COUNT" -gt 1000 ]; then
    echo "⚠️  $ERROR_COUNT errors detected (large log file - showing sample)"
    echo ""
  fi

  echo "Errors found:"
  echo "─────────────────────────────────────"
  # Show first 10 + last 10 errors to avoid missing critical ones
  if [ "$ERROR_COUNT" -gt 20 ]; then
    head -n 10 "$LOG_FILE" | grep -v "Type check"
    echo "... ($((ERROR_COUNT - 20)) more lines) ..."
    tail -n 10 "$LOG_FILE" | grep -v "Type check"
  else
    grep -v "Type check" "$LOG_FILE"
  fi
  echo "─────────────────────────────────────"
  echo ""
  echo "Full log: cat $LOG_FILE"
  echo ""
  echo "⚠️  You can still work on the worktree - fix type errors as you go."

elif echo "$LOG_CONTENT" | grep -q "⏳ Type check started"; then
  # Extract start timestamp
  START_TIME=$(echo "$LOG_CONTENT" | grep "Type check started" | sed 's/.*at //')
  CURRENT_TIME=$(date +%H:%M:%S)

  echo "⏳ Type check still running..."
  echo "   Started at: $START_TIME"
  echo "   Current time: $CURRENT_TIME"
  echo ""
  echo "This usually takes ~30 seconds for a full project scan."
  echo ""
  echo "Check again in a few seconds or view live progress:"
  echo "  tail -f $LOG_FILE"

else
  # Unknown state
  echo "⚠️  Type check in unknown state"
  echo ""
  echo "Log content:"
  cat "$LOG_FILE"
fi
```

## Output Examples

### Success

```
✅ Type check passed
   Completed at: 14:23:45

Worktree is ready for development!
```

### Failed

```
❌ Type check failed
   Completed at: 14:24:12

Errors found:
─────────────────────────────────────
src/components/session-card.tsx:45:12
  Type 'string | undefined' is not assignable to type 'string'

src/utils/format-date.ts:23:8
  Property 'format' does not exist on type 'Date'
─────────────────────────────────────

Full log: cat /tmp/worktree-typecheck-feature-auth.log

⚠️  You can still work on the worktree - fix type errors as you go.
```

### Still Running

```
⏳ Type check still running...
   Started at: 14:22:30
   Current time: 14:22:45

This usually takes ~30 seconds for a full project scan.

Check again in a few seconds or view live progress:
  tail -f /tmp/worktree-typecheck-feature-auth.log
```

### Not Found

```
❌ No type check found for branch: feature/nonexistent

Possible reasons:
1. Worktree was created with --fast flag (type check skipped)
2. Branch name mismatch (use exact branch name)
3. Type check hasn't started yet (wait a few seconds)

Available logs:
  /tmp/worktree-typecheck-feature-auth.log
  /tmp/worktree-typecheck-fix-session-bug.log
```

## Log File Location

Type check logs are stored in `/tmp/worktree-typecheck-{branch-name}.log`

**Branch name normalization**: Slashes (`/`) are replaced with dashes (`-`)

Examples:

- `feature/auth` → `/tmp/worktree-typecheck-feature-auth.log`
- `fix/session-bug` → `/tmp/worktree-typecheck-fix-session-bug.log`

## Integration with /worktree

When `/worktree` creates a background type check, it tells you:

```
⏳ Type check running in background...
📝 Check status: /worktree-status feature/auth
📝 Or view log: cat /tmp/worktree-typecheck-feature-auth.log
```

## Workflow

```
1. Create worktree (instant)
   /worktree feature/auth
   → ✅ Ready in 2s
   → ⏳ Type check running...

2. Verify environment files copied (recommended)
   ls -la .worktrees/feature-auth/.env*
   → Should show: .env, .env.local, .env.e2e, etc.

3. Start coding immediately
   cd .worktrees/feature-auth
   vim src/...

4. Check status when ready
   /worktree-status feature/auth
   → ✅ Type check passed
```

## Environment Files Verification

**Quick check**: Verify `.env.*` files were copied correctly

```bash
# List all copied environment files
ls -la .worktrees/feature-auth/.env*

# Verify specific file exists and has content
test -s .worktrees/feature-auth/.env.local && echo "✅ .env.local present" || echo "❌ .env.local missing"

# Check all expected files at once
for f in .env .env.local .env.e2e .env.staging; do
  test -f .worktrees/feature-auth/$f && echo "✅ $f" || echo "⚠️  $f missing"
done
```

**Manual copy** (if verification fails):

```bash
# Copy missing files from main repo
WORKTREE_DIR=".worktrees/feature-auth"
cp .env.local "$WORKTREE_DIR/"
cp .env.e2e "$WORKTREE_DIR/"
cp .env.staging "$WORKTREE_DIR/"

# Verify copy succeeded
ls -la "$WORKTREE_DIR/.env*"
```

**One-liner for all environments**:

```bash
# Copy only .worktreeinclude listed files (safer - prevents leaking unlisted secrets)
for f in .env .env.local .env.e2e .env.test .env.staging .env.development; do
  [ -f "$f" ] && cp "$f" .worktrees/feature-auth/
done && echo "✅ All listed .env files copied"
```

## Troubleshooting

**"No type check found"**

- Wait 5 seconds after worktree creation
- Check exact branch name (case-sensitive)
- Verify worktree wasn't created with `--fast`

**"Type check still running after 2 minutes"**

- Large codebase may take longer
- Check live progress: `tail -f /tmp/worktree-typecheck-{branch}.log`
- Verify `pnpm tsc --noEmit` works in worktree directory

**Log file cluttered**

```bash
# Clean up old logs (>7 days)
find /tmp -name "worktree-typecheck-*.log" -mtime +7 -delete

# Or clean all worktree logs immediately
rm /tmp/worktree-typecheck-*.log
```

**Recommended maintenance**

```bash
# Add to crontab for weekly cleanup (run every Sunday at 3am)
# crontab -e
0 3 * * 0 find /tmp -name "worktree-typecheck-*.log" -mtime +7 -delete
```
