# Program: Parse Yield Improvement (Boucle C)

## Objectif

Augmenter le ratio de sessions avec un `context` non-vide dans l'index, sans inclure de messages système.

## Métrique cible

```bash
bash scripts/runner-yield.sh
# Doit afficher: METRIC: X% yield (N/M sessions with context)
# Cible: augmentation >= 5 points de pourcentage par rapport au baseline
```

## Scope strict — ne modifier QUE ces fonctions

- `get_first_user_message()` (ligne ~190-220)
- `_is_system_injection()` (ligne ~581-584)
- `_SYSTEM_INJECTION_MARKERS` (ligne ~567-578)

Ne PAS toucher : `extract_all_user_messages()`, `parse_session()`, `build_index()`.

## Problème identifié

### 1. Filtres trop agressifs dans `get_first_user_message()`

La fonction actuelle filtre correctement les messages système mais peut rejeter des messages utilisateur légitimes qui :
- Commencent par `<` (balises XML/HTML dans des questions de dev)
- Sont des messages avec du contexte utile mais contenant des fragments de chemins système

### 2. `_is_system_injection()` trop large

Les markers actuels incluent `'florianbruniaux/sites/'` qui peut rejeter des messages légitimes mentionnant des projets situés dans `~/Sites/`.

### 3. Pas de fallback sur le deuxième message

`get_first_user_message()` s'arrête au premier message de type user, même si celui-ci est filtré. Elle ne tente pas le deuxième ou troisième message.

**Fix attendu** : essayer les N premiers messages user jusqu'à en trouver un valide (cap à 5 pour ne pas lire tout le fichier).

## Contraintes absolues

1. Ne PAS inclure de messages système — les filtres existent pour une raison valide
2. Chaque session récupérée en plus doit avoir un context lisible par un humain (pas de garbage)
3. Les sessions existantes DOIVENT garder le même context (pas de régression sur ce qui était déjà indexé)
4. Pas de dépendance externe

## Approche recommandée

### Fallback sur messages suivants

```python
def get_first_user_message(filepath: Path) -> Optional[str]:
    """Extract first significant user message, trying up to 5 candidates."""
    MAX_CANDIDATES = 5
    candidates_tried = 0
    try:
        with open(filepath, 'r') as f:
            for line in f:
                if not line.strip():
                    continue
                try:
                    entry = json.loads(line)
                    if entry.get('type') != 'user':
                        continue
                    content = entry.get('message', {}).get('content', '')
                    if not isinstance(content, str):
                        continue
                    if content.startswith('<'):
                        candidates_tried += 1
                        if candidates_tried >= MAX_CANDIDATES:
                            break
                        continue
                    # Found valid message
                    return content[:60].replace('\n', ' ')
                except json.JSONDecodeError:
                    continue
    except Exception:
        pass
    return None
```

### Resserrer `_SYSTEM_INJECTION_MARKERS`

Remplacer les markers trop larges par des patterns plus spécifiques :

```python
_SYSTEM_INJECTION_MARKERS = (
    'this session is being continued',
    'read the full transcript',
    'context summary below covers',
    'exact snippets error messages content',
    'exiting plan mode',
    'task tools haven',
    'teamcreate tool team parallelize',
    '-users-florianbruniaux-',            # encoded path in compact messages
    # Retiré: 'florianbruniaux/sites/' (trop large, rejette des messages légitimes)
    # Retiré: 'florianbruniaux/.claude/projects' (même raison)
)
```

## Validation

```bash
# Baseline
bash scripts/runner-yield.sh

# Après modification
bash scripts/runner-yield.sh

# Vérification manuelle : les nouvelles sessions doivent avoir un context lisible
# Comparer les sessions qui ont maintenant un context avec celles qui n'en avaient pas
python3 -c "
import json
with open('$HOME/.claude/sessions-index.jsonl') as f:
    sessions = [json.loads(l) for l in f if l.strip()]

# Afficher quelques contexts pour vérification qualitative
for s in sessions[:10]:
    print(s['id'][:20], '|', repr(s['context'][:50]))
"
```

## Attention : faux positifs

Vérifier que les nouveaux contexts récupérés ne sont pas :
- Des résumés de compaction (`This session is being continued...`)
- Des messages de système Plan Mode
- Des chemins de fichiers seuls
- Des messages d'ack très courts (<10 chars, déjà filtrés)
