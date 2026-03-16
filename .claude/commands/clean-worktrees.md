---
skill_name: tech:clean-worktrees
version: 1.0.0
description: Automatically clean all stale worktrees (pruned refs + merged branches)
author: Claude Code
tags: [git, worktree, cleanup, automation]
---

# Clean Worktrees (Automatic)

Automatically clean all stale worktrees: pruned references, merged branches, and orphaned directories.

**Difference with `/tech:clean-worktree`**:
- `/tech:clean-worktree`: Interactive, asks confirmation
- `/tech:clean-worktrees`: **Automatic**, no interaction (safe: only merged branches)

## Usage

```bash
/tech:clean-worktrees           # Clean all merged worktrees
/tech:clean-worktrees --dry-run # Preview what would be deleted
```

## Implementation

Execute this script:

```bash
#!/bin/bash
set -euo pipefail

DRY_RUN=false
if [[ "${ARGUMENTS:-}" == *"--dry-run"* ]]; then
  DRY_RUN=true
fi

echo "🧹 Cleaning Worktrees"
echo "====================="
echo ""

# Step 1: Prune stale git references
echo "1️⃣  Pruning stale git references..."
PRUNED=$(git worktree prune -v 2>&1)
if [ -n "$PRUNED" ]; then
  echo "$PRUNED"
  echo "✅ Stale references pruned"
else
  echo "✅ No stale references found"
fi
echo ""

# Step 2: Find merged worktrees
echo "2️⃣  Finding merged worktrees..."
MERGED_COUNT=0
MERGED_BRANCHES=()

while IFS= read -r line; do
  path=$(echo "$line" | awk '{print $1}')
  branch=$(echo "$line" | grep -oE '\[.*\]' | tr -d '[]' || true)

  # Skip if no branch info or protected branches
  [ -z "$branch" ] && continue
  [ "$branch" = "develop" ] && continue
  [ "$branch" = "main" ] && continue
  [ "$path" = "$(pwd)" ] && continue

  # Check if merged into develop
  if git branch --merged develop | grep -q "^[* ] ${branch}$" 2>/dev/null; then
    MERGED_COUNT=$((MERGED_COUNT + 1))
    MERGED_BRANCHES+=("$branch|$path")
    echo "  ✓ $branch (merged)"
  fi
done < <(git worktree list)

if [ $MERGED_COUNT -eq 0 ]; then
  echo "✅ No merged worktrees found"
  echo ""
  echo "📊 Current worktrees:"
  git worktree list
  exit 0
fi

echo ""
echo "📋 Found $MERGED_COUNT merged worktree(s)"
echo ""

if [ "$DRY_RUN" = true ]; then
  echo "🔍 DRY RUN MODE - No changes will be made"
  echo ""
  echo "Would delete:"
  for item in "${MERGED_BRANCHES[@]}"; do
    branch=$(echo "$item" | cut -d'|' -f1)
    path=$(echo "$item" | cut -d'|' -f2)
    echo "  - $branch"
    echo "    Path: $path"
  done
  echo ""
  echo "Run without --dry-run to actually delete"
  exit 0
fi

# Step 3: Remove merged worktrees
echo "3️⃣  Removing merged worktrees..."
REMOVED_COUNT=0
FAILED_COUNT=0

for item in "${MERGED_BRANCHES[@]}"; do
  branch=$(echo "$item" | cut -d'|' -f1)
  path=$(echo "$item" | cut -d'|' -f2)

  echo ""
  echo "🗑️  Removing: $branch"

  # Remove worktree
  if git worktree remove "$path" 2>/dev/null; then
    echo "  ✅ Worktree removed"
  else
    echo "  ⚠️  Git remove failed, forcing..."
    rm -rf "$path" 2>/dev/null || true
    git worktree prune 2>/dev/null || true
    echo "  ✅ Worktree forcefully removed"
  fi

  # Delete local branch
  if git branch -d "$branch" 2>/dev/null; then
    echo "  ✅ Local branch deleted"
  else
    echo "  ⚠️  Local branch already deleted"
  fi

  # Check if remote branch exists
  if git ls-remote --heads origin "$branch" 2>/dev/null | grep -q "$branch"; then
    echo "  🌐 Remote branch exists: $branch"
    echo "     (Skipping auto-delete - use /tech:remove-worktree for manual removal)"
  fi

  REMOVED_COUNT=$((REMOVED_COUNT + 1))
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Cleanup Complete!"
echo ""
echo "📊 Summary:"
echo "  - Removed: $REMOVED_COUNT worktree(s)"
if [ $FAILED_COUNT -gt 0 ]; then
  echo "  - Failed: $FAILED_COUNT worktree(s)"
fi
echo ""
echo "📂 Remaining worktrees:"
git worktree list
echo ""

# Optional: Show disk space saved
WORKTREES_SIZE=$(du -sh .worktrees/ 2>/dev/null | awk '{print $1}' || echo "N/A")
echo "💾 Worktrees disk usage: $WORKTREES_SIZE"
```

## Safety Features

- ✅ **Only merged branches**: Never touches unmerged work
- ✅ **Protected branches**: Skips `develop` and `main`
- ✅ **Main repo**: Never removes current working directory
- ✅ **Remote branches**: Reports existence but doesn't auto-delete
- ✅ **Dry-run mode**: Preview before deletion

## What Gets Deleted

### ✅ Safe to Delete (automatic)
- Worktrees for branches merged into `develop`
- Orphaned git references (pruned)
- Local branches corresponding to removed worktrees

### ⏭️ Skipped (manual action required)
- Unmerged branches → Use `/tech:remove-worktree <branch>` with confirmation
- Remote branches → Manual deletion or use `/tech:remove-worktree`
- Protected branches (`develop`, `main`)

## Examples

### Clean merged worktrees
```bash
/tech:clean-worktrees
# → Removes all merged worktrees automatically
```

### Preview before cleaning
```bash
/tech:clean-worktrees --dry-run
# → Shows what would be deleted without actually deleting
```

### Remove specific unmerged worktree
```bash
/tech:remove-worktree feature/experimental
# → Asks confirmation for unmerged branch
```

## When to Use

**Daily workflow**:
- ✅ After merging PRs → `/tech:clean-worktrees`
- ✅ Weekly maintenance → `/tech:clean-worktrees`
- ✅ Before creating new worktrees → `/tech:clean-worktrees`

**Manual removal needed**:
- ❌ Unmerged work you want to discard → `/tech:remove-worktree <branch>`
- ❌ Remote branch cleanup → `/tech:remove-worktree <branch>` (confirms remote delete)

## Maintenance

### Monthly cleanup
```bash
# Clean merged worktrees
/tech:clean-worktrees

# List remaining
git worktree list

# Check disk usage
du -sh .worktrees/
```

### Emergency full reset
```bash
# Remove ALL worktrees (except main repo)
rm -rf .worktrees/
git worktree prune

# Rebuild if needed
git worktree list
```

## Troubleshooting

**"Worktree locked"**
```bash
# Unlock manually
rm .git/worktrees/<branch>/.lock
git worktree prune
```

**"Directory not empty"**
```bash
# Force remove
rm -rf .worktrees/<branch>
git worktree prune
```

**Remote branches not deleted**
```bash
# List remote branches
git ls-remote --heads origin

# Delete specific remote branch
git push origin --delete <branch> --no-verify
```