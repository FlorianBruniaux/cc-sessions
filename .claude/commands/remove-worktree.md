---
name: remove-worktree
description: Remove a specific worktree cleanly (directory + git reference + branch)
argument-hint: "<branch-name>"
---

# Remove Worktree

Remove a specific worktree properly, cleaning up directory, git references, and optionally the branch.

## Usage

```bash
/tech:remove-worktree feature/auth
/tech:remove-worktree fix/session-bug
```

## Implementation

Execute this script with branch name from `$ARGUMENTS`:

```bash
#!/bin/bash
set -euo pipefail

BRANCH_NAME="$ARGUMENTS"

if [ -z "$BRANCH_NAME" ]; then
  echo "❌ Usage: /tech:remove-worktree <branch-name>"
  echo ""
  echo "Example:"
  echo "  /tech:remove-worktree feature/auth"
  exit 1
fi

# Normalize branch name (remove feature/ prefix if in path)
WORKTREE_PATH=".worktrees/${BRANCH_NAME#feature/}"
WORKTREE_PATH="${WORKTREE_PATH#fix/}"

echo "🔍 Checking worktree: $BRANCH_NAME"
echo ""

# Check if worktree exists in git
if ! git worktree list | grep -q "$BRANCH_NAME"; then
  echo "❌ Worktree not found: $BRANCH_NAME"
  echo ""
  echo "Available worktrees:"
  git worktree list
  exit 1
fi

# Get worktree path from git
WORKTREE_FULL_PATH=$(git worktree list | grep "$BRANCH_NAME" | awk '{print $1}')

# Safety check: never remove main repo
if [ "$WORKTREE_FULL_PATH" = "$(pwd)" ]; then
  echo "❌ Cannot remove main repository worktree"
  exit 1
fi

# Safety check: never remove develop or main
if [ "$BRANCH_NAME" = "develop" ] || [ "$BRANCH_NAME" = "main" ]; then
  echo "❌ Cannot remove $BRANCH_NAME (protected branch)"
  exit 1
fi

echo "📂 Worktree path: $WORKTREE_FULL_PATH"
echo "🌿 Branch: $BRANCH_NAME"
echo ""

# Check if branch is merged
IS_MERGED=false
if git branch --merged develop | grep -q "^[* ] ${BRANCH_NAME}$"; then
  IS_MERGED=true
  echo "✅ Branch is merged into develop (safe to delete)"
else
  echo "⚠️  Branch is NOT merged into develop"
fi
echo ""

# Ask confirmation if not merged
if [ "$IS_MERGED" = false ]; then
  echo "⚠️  This will DELETE unmerged work. Continue? [y/N]"
  read -r confirm
  if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "Aborted."
    exit 0
  fi
fi

# Remove worktree
echo "🗑️  Removing worktree..."
if git worktree remove "$WORKTREE_FULL_PATH" 2>/dev/null; then
  echo "✅ Worktree removed: $WORKTREE_FULL_PATH"
else
  # Fallback: force remove if git fails
  echo "⚠️  Git remove failed, forcing removal..."
  rm -rf "$WORKTREE_FULL_PATH"
  git worktree prune
  echo "✅ Worktree forcefully removed"
fi

# Delete branch
echo ""
echo "🌿 Deleting branch..."
if [ "$IS_MERGED" = true ]; then
  # Safe delete (merged)
  if git branch -d "$BRANCH_NAME" 2>/dev/null; then
    echo "✅ Branch deleted (local): $BRANCH_NAME"
  else
    echo "⚠️  Local branch already deleted or not found"
  fi
else
  # Force delete (not merged)
  if git branch -D "$BRANCH_NAME" 2>/dev/null; then
    echo "✅ Branch force-deleted (local): $BRANCH_NAME"
  else
    echo "⚠️  Local branch already deleted or not found"
  fi
fi

# Delete remote branch (if exists)
echo ""
echo "🌐 Checking remote branch..."
if git ls-remote --heads origin "$BRANCH_NAME" | grep -q "$BRANCH_NAME"; then
  echo "⚠️  Remote branch exists. Delete it? [y/N]"
  read -r confirm_remote
  if [ "$confirm_remote" = "y" ] || [ "$confirm_remote" = "Y" ]; then
    if git push origin --delete "$BRANCH_NAME" --no-verify 2>/dev/null; then
      echo "✅ Remote branch deleted: $BRANCH_NAME"
    else
      echo "❌ Failed to delete remote branch (may require permissions)"
    fi
  else
    echo "⏭️  Skipped remote branch deletion"
  fi
else
  echo "ℹ️  No remote branch found"
fi

echo ""
echo "✅ Cleanup complete!"
echo ""
echo "📊 Remaining worktrees:"
git worktree list
```

## Safety Features

- ✅ Never removes `develop` or `main`
- ✅ Asks confirmation for unmerged branches
- ✅ Cleans git references, directory, and branch
- ✅ Optional remote branch deletion
- ✅ Fallback to force removal if git fails

## Manual Override

For force removal without confirmation:

```bash
git worktree remove --force <path>
git branch -D <branch>
git push origin --delete <branch> --no-verify
```

## After Removal

Clean up any remaining orphaned references:

```bash
git worktree prune -v
```
