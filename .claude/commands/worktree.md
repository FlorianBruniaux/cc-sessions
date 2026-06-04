---
name: worktree
description: Create an isolated git worktree with instant feedback and background type check
model: haiku
argument-hint: "<branch-name> [--fast|--skip-install|--isolated]"
---

# Git Worktree Setup (Optimized)

Create isolated git worktrees with instant feedback and background verification.

**Performance**: ~2s setup + 30s background type check (vs 32s blocking)

## Usage

```bash
/worktree feature/auth              # Creates worktree + symlink node_modules
/worktree fix/typo --fast           # Skip type check (instant)
/worktree feature/payment --skip-install  # No deps handling
/worktree feature/migration --isolated    # Install separate node_modules
```

**Behavior**: The command creates the worktree and displays the path. Navigate to it manually with `cd .worktrees/{branch-name}`.

**⚠️ Important - Claude Context**: If Claude Code is currently running (from `/app` or another worktree), you must restart it in the new worktree context:
```bash
/exit                                    # Exit current Claude session
cd .worktrees/fix-bug-name              # Navigate to worktree
claude                                   # Start Claude in worktree context
```

If Claude is not running, simply navigate and start:
```bash
cd .worktrees/fix-bug-name
claude
```

Check type check status: `/worktree-status feature/auth`

## Branch Naming Convention

**IMPORTANT**: Always use Git branch naming conventions with slashes:

- ✅ `feature/new-component` → Branch: `feature/new-component`, Directory: `.worktrees/feature-new-component`
- ✅ `fix/bug-name` → Branch: `fix/bug-name`, Directory: `.worktrees/fix-bug-name`
- ❌ `feature-new-component` → Wrong: Missing category prefix

**How it works**:
- Input branch name keeps slashes: `fix/workplan-background`
- Git branch created with slashes: `fix/workplan-background`
- Worktree directory name converts slashes to dashes: `.worktrees/fix-workplan-background`

This allows proper Git branch hierarchy while avoiding filesystem issues with slashes in directory names.

## Implementation

Execute this **single bash script** with branch name from `$ARGUMENTS`:

```bash
#!/bin/bash
set -euo pipefail

# Cleanup background processes on exit
trap 'kill $(jobs -p) 2>/dev/null || true' EXIT

# Validate git repository - always use main repo root (not worktree root)
GIT_COMMON_DIR="$(git rev-parse --git-common-dir 2>/dev/null)"
if [ -z "$GIT_COMMON_DIR" ]; then
  echo "❌ Not in a git repository"
  echo "Navigate to a git repository first"
  exit 1
fi
REPO_ROOT="$(cd "$GIT_COMMON_DIR/.." && pwd)"

# Parse flags (preserve original for WORKTREE_DIR calculation)
RAW_ARGS="$ARGUMENTS"
BRANCH_NAME="$RAW_ARGS"
SKIP_TYPECHECK=false
SKIP_INSTALL=false
ISOLATED_INSTALL=false

if [[ "$RAW_ARGS" == *"--fast"* ]]; then
  SKIP_TYPECHECK=true
  BRANCH_NAME="${BRANCH_NAME// --fast/}"
fi
if [[ "$RAW_ARGS" == *"--skip-install"* ]]; then
  SKIP_INSTALL=true
  BRANCH_NAME="${BRANCH_NAME// --skip-install/}"
fi
if [[ "$RAW_ARGS" == *"--isolated"* ]]; then
  ISOLATED_INSTALL=true
  BRANCH_NAME="${BRANCH_NAME// --isolated/}"
fi

# Validate branch name (no spaces or special chars that break paths/git)
if [[ "$BRANCH_NAME" =~ [[:space:]\$\`] ]]; then
  echo "❌ Invalid branch name (spaces or special characters not allowed)"
  exit 1
fi

# Validate git-forbidden characters in branch name
if [[ "$BRANCH_NAME" =~ [~^:?*\\\[\]] ]]; then
  echo "❌ Invalid branch name (git forbidden characters: ~ ^ : ? * [ ])"
  exit 1
fi

# Paths (after flag parsing) - sanitize slashes to avoid nested directories
WORKTREE_NAME="${BRANCH_NAME//\//-}"
WORKTREE_DIR="$REPO_ROOT/.worktrees/$WORKTREE_NAME"
LOG_FILE="/tmp/worktree-typecheck-${WORKTREE_NAME}.log"

# 1. Check .gitignore (fail-fast)
if ! grep -qE "^\.worktrees/?$" "$REPO_ROOT/.gitignore" 2>/dev/null; then
  echo "❌ .worktrees/ not in .gitignore"
  echo "Run: echo '.worktrees/' >> .gitignore && git add .gitignore && git commit -m 'chore: ignore worktrees'"
  exit 1
fi

# 2. Create worktree (fail-fast)
echo "Creating worktree for $BRANCH_NAME..."
# Ensure parent directory exists
mkdir -p "$REPO_ROOT/.worktrees"
if ! git worktree add "$WORKTREE_DIR" -b "$BRANCH_NAME" 2>/tmp/worktree-error.log; then
  echo "❌ Failed to create worktree"
  cat /tmp/worktree-error.log
  exit 1
fi

# 3. Handle dependencies (symlink by default, install if --isolated)
if [ "$SKIP_INSTALL" = false ]; then
  if [ "$ISOLATED_INSTALL" = true ]; then
    # Install separate node_modules (only when explicitly requested)
    if ! command -v pnpm &>/dev/null; then
      echo "❌ pnpm not found"
      echo "Install with: npm install -g pnpm"
      exit 1
    fi
    echo "📦 Installing isolated dependencies (this may take up to 2 minutes)..."
    (cd "$WORKTREE_DIR" && pnpm install --frozen-lockfile > /tmp/worktree-install.log 2>&1) &
    INSTALL_PID=$!
  else
    # Symlink to shared node_modules (default - saves 1.5GB per worktree)
    echo "🔗 Linking shared node_modules..."
    ln -sf "$REPO_ROOT/node_modules" "$WORKTREE_DIR/node_modules"
    INSTALL_PID=""
  fi
else
  INSTALL_PID=""
fi

# 4. Copy files listed in .worktreeinclude (non-blocking)
(
  INCLUDE_FILE="$REPO_ROOT/.worktreeinclude"
  COPY_COUNT=0
  if [ -f "$INCLUDE_FILE" ]; then
    while IFS= read -r entry || [ -n "$entry" ]; do
      [[ "$entry" =~ ^#.*$ || -z "$entry" ]] && continue
      entry="$(echo "$entry" | xargs)"
      SRC="$REPO_ROOT/$entry"
      if [ -e "$SRC" ]; then
        DEST_DIR="$(dirname "$WORKTREE_DIR/$entry")"
        mkdir -p "$DEST_DIR"
        cp -R "$SRC" "$WORKTREE_DIR/$entry"
        COPY_COUNT=$((COPY_COUNT + 1))
      fi
    done < "$INCLUDE_FILE"
    if [ "$COPY_COUNT" -eq 0 ]; then
      echo "⚠️  No files from .worktreeinclude found" > /tmp/worktree-env.log
    fi
  else
    cp "$REPO_ROOT"/.env* "$WORKTREE_DIR/" 2>/dev/null || \
      echo "⚠️  No .env files found" > /tmp/worktree-env.log
  fi
) &
ENV_PID=$!

# 5. Wait for parallel operations (with timeout)
if [ -n "$INSTALL_PID" ]; then
  echo "⏳ Installing dependencies (this may take up to 2 minutes)..."

  # Wait with 120s timeout to prevent indefinite hang (if timeout command available)
  if command -v timeout >/dev/null 2>&1; then
    if ! timeout 120 wait $INSTALL_PID 2>/dev/null; then
      # Check if timeout or actual failure
      if ps -p $INSTALL_PID >/dev/null 2>&1; then
        echo "⚠️  Install timeout (>2min) - process still running"
        kill $INSTALL_PID 2>/dev/null || true
        wait $INSTALL_PID 2>/dev/null || true  # Cleanup zombie process
      else
        # Process finished with error
        echo "❌ Dependencies installation failed"
        echo "Check log: cat /tmp/worktree-install.log"
        exit 1
      fi
    fi
  else
    # Fallback: wait without timeout if command not available
    if ! wait $INSTALL_PID 2>/dev/null; then
      echo "❌ Dependencies installation failed"
      echo "Check log: cat /tmp/worktree-install.log"
      exit 1
    fi
  fi
fi
# Always wait for env copy process (with timeout if available)
if command -v timeout >/dev/null 2>&1; then
  timeout 10 wait $ENV_PID 2>/dev/null || true
else
  wait $ENV_PID 2>/dev/null || true
fi

# 6. Background type check (unless --fast)
if [ "$SKIP_TYPECHECK" = false ] && [ -f "$WORKTREE_DIR/tsconfig.json" ]; then
  (
    cd "$WORKTREE_DIR"
    echo "⏳ Type check started at $(date +%H:%M:%S)" > "$LOG_FILE"
    if pnpm tsc --noEmit >> "$LOG_FILE" 2>&1; then
      echo "✅ Type check passed at $(date +%H:%M:%S)" >> "$LOG_FILE"
    else
      echo "❌ Type check failed at $(date +%H:%M:%S)" >> "$LOG_FILE"
    fi
  ) &
  TYPECHECK_RUNNING=true
else
  TYPECHECK_RUNNING=false
fi

# 7. Report (instant feedback)
echo ""
echo "✅ Worktree ready: $WORKTREE_DIR"

if [ "$SKIP_INSTALL" = false ]; then
  if [ "$ISOLATED_INSTALL" = true ]; then
    echo "✅ Dependencies installed (isolated)"
  else
    echo "✅ Dependencies linked (shared node_modules)"
  fi
fi

if [ -f "/tmp/worktree-env.log" ]; then
  cat /tmp/worktree-env.log
else
  echo "✅ Environment files copied"
fi

if [ "$TYPECHECK_RUNNING" = true ]; then
  echo "⏳ Type check running in background..."
  echo "📝 Check status: /worktree-status $BRANCH_NAME"
  echo "📝 Or view log: cat $LOG_FILE"
elif [ "$SKIP_TYPECHECK" = true ]; then
  echo "⚡ Type check skipped (--fast mode)"
fi

echo ""
echo "🚀 Next steps:"
echo ""
echo "If Claude Code is running:"
echo "   1. /exit"
echo "   2. cd $WORKTREE_DIR"
echo "   3. claude"
echo ""
echo "If Claude Code is NOT running:"
echo "   cd $WORKTREE_DIR && claude"
echo ""
echo "✅ Ready to work!"
```

**Note**: After creation, manually navigate to the worktree directory with `cd .worktrees/{branch-name}` to start working.

## Key Changes from v1

| Aspect                | Before                     | After                        |
| --------------------- | -------------------------- | ---------------------------- |
| **Execution**         | 7 sequential Bash calls    | 1 unified script             |
| **Duration**          | 32s blocking               | <1s instant + 30s background |
| **Disk usage**        | 1.5GB per worktree         | 0KB (symlink)                |
| **Shell context**     | Multiple cd (fails)        | Absolute paths (reliable)    |
| **Type check**        | Blocking                   | Background (optional)        |
| **User control**      | None                       | --fast, --skip-install flags |
| **Feedback**          | 7 intermediate messages    | 1 final report               |
| **Working directory** | Manual navigation required | Auto-cd to worktree          |

## Environment Files (.env.\*)

**Auto-copy behavior**: Files listed in `.worktreeinclude` are automatically copied during worktree creation.

**Current config** (`.worktreeinclude`):

```
.env
.env.local
.env.e2e
.env.test
.env.staging
.env.development
.claude/settings.local.json
.auth/
```

**Verify after creation**:

```bash
# Check which .env files were copied
ls -la .worktrees/feature-name/.env*

# Verify specific environment file
cat .worktrees/feature-name/.env.local | head -n 5
```

**Manual copy** (if auto-copy failed):

```bash
# Copy only .worktreeinclude listed files (safer - prevents leaking unlisted secrets)
for f in .env .env.local .env.e2e .env.test .env.staging .env.development; do
  [ -f "$f" ] && cp "$f" .worktrees/feature-name/ && echo "✅ $f copied"
done

# Copy specific environment
cp .env.staging .worktrees/feature-name/

# Copy with verification
cp .env.local .worktrees/feature-name/ && echo "✅ .env.local copied"
```

**Add new environment file to auto-copy**:

```bash
# Edit .worktreeinclude
echo ".env.preview" >> .worktreeinclude
```

## Flags

### `--fast`

Skip type check entirely (instant setup).

**Use when**: Quick fixes, typos, documentation changes.

```bash
/worktree fix/typo --fast
→ ✅ Ready in 2s (no type check)
```

### `--skip-install`

Skip dependency handling entirely.

**Use when**: Manual dependency management needed.

```bash
/worktree feature/ui-polish --skip-install
→ ✅ Ready in 1s (no deps handling)
```

### `--isolated`

Install separate `node_modules` (1.5GB) instead of symlinking.

**Use when**: Branch requires different dependency versions (rare).

```bash
/worktree feature/migration-v2 --isolated
→ 📦 Installing isolated dependencies...
→ ✅ Ready in 2min (1.5GB installed)
```

**Default behavior (no flag)**: Symlinks to shared `node_modules` → **Saves 1.5GB per worktree**

## Status Check

Use `/worktree-status` to check background type check:

```bash
/worktree-status feature/auth
→ ✅ Type check passed (0 errors)
→ ❌ Type check failed (3 errors) - see log
→ ⏳ Still running... (started 10s ago)
```

## Error Handling

### Critical Errors (fail-fast)

- ❌ `.worktrees/` not in .gitignore → Manual fix required
- ❌ Git worktree creation fails → Check branch name conflicts
- ❌ Branch already exists → Use different name or delete old branch

### Warnings (continue)

- ⚠️ No .env files found → May need manual configuration
- ⚠️ Type check failed → Can still work, fix issues later
- ⚠️ Install warnings → Non-critical, continue

## Cleanup

```bash
# Remove worktree (replace slashes with dashes)
git worktree remove .worktrees/${BRANCH_NAME//\//-}

# Or force if uncommitted changes
git worktree remove --force .worktrees/${BRANCH_NAME//\//-}

# Prune stale worktrees
git worktree prune
```

## Performance Comparison

| Operation            | v1 (blocking) | v2 (hybrid) | Improvement    |
| -------------------- | ------------- | ----------- | -------------- |
| Initial feedback     | 32s           | 2s          | **94% faster** |
| Full verification    | 32s           | 2s + 30s bg | Same safety    |
| Quick fixes (--fast) | 32s           | 2s          | **94% faster** |

## Troubleshooting

**"worktree already exists"**

```bash
git worktree remove .worktrees/$BRANCH_NAME
# Then retry
```

**"branch already exists"**

```bash
git branch -D $BRANCH_NAME
# Then retry
```

**Type check log not found**

```bash
ls /tmp/worktree-typecheck-*.log
# Check if type check started
```
