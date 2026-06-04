---
name: clean-worktree
description: Clean stale worktrees (pruned, merged, or orphaned branches)
---

# Clean Worktrees Skill

## Purpose

Nettoie les worktrees obsolètes (merged, pruned, branches orphelines).

## Workflow

### 1. Audit worktrees

```bash
echo "=== Worktrees Status ==="
git worktree list
echo ""
```

### 2. Prune references stale

```bash
echo "=== Pruning stale references ==="
git worktree prune
echo ""
```

### 3. Detect merged branches

```bash
echo "=== Merged branches (safe to delete) ==="
while IFS= read -r line; do
    path=$(echo "$line" | awk '{print $1}')
    branch=$(echo "$line" | grep -oE '\[.*\]' | tr -d '[]')
    [ -z "$branch" ] && continue
    [ "$branch" = "develop" ] && continue
    [ "$branch" = "main" ] && continue

    # Check if merged into develop
    if git branch --merged develop | grep -q "^[* ] ${branch}$"; then
        echo "  - $branch (at $path) — MERGED"
    fi
done < <(git worktree list)
echo ""
```

### 4. Interactive cleanup

```bash
echo "=== Clean merged worktrees? [y/N] ==="
read -r confirm
if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
    while IFS= read -r line; do
        path=$(echo "$line" | awk '{print $1}')
        branch=$(echo "$line" | grep -oE '\[.*\]' | tr -d '[]')
        [ -z "$branch" ] && continue
        [ "$branch" = "develop" ] && continue
        [ "$branch" = "main" ] && continue

        if git branch --merged develop | grep -q "^[* ] ${branch}$"; then
            echo "  Removing $branch..."
            git worktree remove "$path" 2>/dev/null || rm -rf "$path"
            git branch -d "$branch" 2>/dev/null || echo "    (branch already deleted)"
        fi
    done < <(git worktree list)
    echo "Done."
else
    echo "Aborted."
fi
```

## Safety

- **Never** removes `develop` or `main` worktrees
- **Only** removes merged branches (safe)
- **Asks confirmation** before deletion
- Cleans both worktree reference AND physical directory

## Manual Override

Pour supprimer un worktree non-merged (force) :

```bash
git worktree remove --force <path>
git branch -D <branch_name>
```

## Disk Space Check

```bash
echo ""
echo "=== Disk usage ==="
du -sh .worktrees/ 2>/dev/null || echo "No .worktrees directory"
du -sh . | tail -1
```