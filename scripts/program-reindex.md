# Program: Reindex Throughput Optimization (Boucle A)

## Objectif

Améliorer la vitesse du cold reindex de `cc-sessions reindex` sans changer le format de l'index JSONL ni ajouter de dépendances.

## Métrique cible

```bash
bash scripts/runner-reindex.sh
# Doit afficher: METRIC: Xs (N sessions indexed)
# Cible: réduction >= 30% du temps de base
```

## Scope strict — ne modifier QUE ces fonctions

- `parse_session()` (ligne ~266-307)
- `build_index()` (ligne ~310-330)
- `get_first_user_message()` (ligne ~190-220)

Ne PAS toucher : `save_index()`, `load_index()`, le format JSONL, les imports.

## Problèmes identifiés

### 1. Double lecture de fichier dans `parse_session()`

Actuellement, `parse_session()` lit le fichier deux fois :
- Une fois via `get_first_user_message(filepath)` pour extraire le contexte
- Une deuxième fois en boucle for pour trouver `gitBranch`

**Fix attendu** : lire le fichier une seule fois, extraire `context` ET `branch` en même passage.

### 2. I/O potentiellement non-bufférisé dans `build_index()`

`glob()` sur chaque répertoire peut être remplacé par `os.scandir()` qui est plus rapide car évite la création d'objets `Path` intermédiaires.

### 3. stat() redondant

`filepath.stat()` est appelé dans `build_index()` pour l'mtime, mais `parse_session()` appelle aussi `filepath.stat()`. Passer `mtime` en paramètre évite le double syscall.

## Contraintes absolues

1. Le format de l'index JSONL NE DOIT PAS changer (même clés, même structure)
2. L'index produit doit avoir le même nombre d'entrées (+/- 2) qu'avant l'optimisation
3. Zéro dépendance externe (stdlib only)
4. Les sessions `agent-*` doivent toujours être exclues
5. Les sessions sans context lisible doivent toujours être exclues (pas de baisse de qualité)

## Validation

```bash
# Baseline : mesurer avant
bash scripts/runner-reindex.sh

# Appliquer les changements, puis mesurer après
bash scripts/runner-reindex.sh

# Vérification manuelle : les 5 premières entrées de l'index doivent avoir
# les mêmes champs qu'avant : id, project, mtime, branch, context, timestamp
head -5 ~/.claude/sessions-index.jsonl | python3 -c "
import sys, json
for line in sys.stdin:
    d = json.loads(line)
    required = {'id', 'project', 'mtime', 'branch', 'context', 'timestamp'}
    missing = required - set(d.keys())
    if missing:
        print(f'MISSING FIELDS: {missing}')
    else:
        print('OK:', d['id'][:20], '|', d['context'][:40])
"
```

## Exemple de refactoring attendu pour `parse_session()`

```python
def parse_session(filepath: Path, mtime: float = None) -> Optional[Dict]:
    """Extract session metadata — single file read."""
    session_id = filepath.stem
    if session_id.startswith('agent-'):
        return None

    if mtime is None:
        mtime = filepath.stat().st_mtime

    context = None
    branch = "unknown"

    try:
        with open(filepath, 'r') as f:
            for line in f:
                if not line.strip():
                    continue
                try:
                    entry = json.loads(line)

                    # Extract branch from first gitBranch field seen
                    if branch == "unknown":
                        git_branch = entry.get('gitBranch')
                        if git_branch:
                            branch = git_branch

                    # Extract context from first significant user message
                    if context is None and entry.get('type') == 'user':
                        content = entry.get('message', {}).get('content', '')
                        if isinstance(content, str) and not content.startswith('<'):
                            context = content[:60].replace('\n', ' ')

                    # Stop early once we have both
                    if context is not None and branch != "unknown":
                        break

                except json.JSONDecodeError:
                    continue
    except Exception:
        pass

    if not context:
        return None

    return {
        "id": session_id,
        "project": filepath.parent.name,
        "mtime": mtime,
        "branch": branch,
        "context": context,
        "timestamp": datetime.fromtimestamp(mtime).isoformat()
    }
```

Et dans `build_index()`, passer `file_mtime` en paramètre :

```python
session = parse_session(filepath, mtime=file_mtime)
```
