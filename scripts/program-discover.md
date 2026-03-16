# Program: Discover Speed Optimization (Boucle B)

## Objectif

Réduire le temps d'exécution de `cc-sessions --all discover --since 30d` en remplaçant le clustering O(n²) par un algorithme plus efficace.

## Métrique cible

```bash
bash scripts/runner-discover.sh
# Doit afficher: METRIC: Xs (N patterns)
# Cible: réduction >= 50% du temps de base
```

## Scope strict — ne modifier QUE ces fonctions

- `discover_patterns()` (ligne ~725-948)
- `token_overlap()` (ligne ~622-627)
- `extract_ngrams()` (ligne ~617-619)
- `normalize_text()` (ligne ~606-614)

Ne PAS toucher : `collect_sessions_data()`, `load_discover_cache()`, `save_discover_cache()`, `cmd_discover()`.

## Problèmes identifiés

### 1. Clustering O(n²) dans `discover_patterns()` (Step 4)

Le clustering Jaccard compare chaque paire de n-grams gardés. Avec N n-grams fréquents, c'est O(N²) comparaisons. Sur un corpus de 30 jours avec des centaines de sessions, N peut atteindre plusieurs milliers.

**Bottleneck exact** : la double boucle `for i ... for j` dans Step 4 (lignes ~802-813).

**Fix attendu** : remplacer par un groupement par clé de hachage. Les n-grams avec suffisamment de tokens en commun auront des clés similaires. Approche recommandée : sorted tokens comme clé de cluster.

### 2. Recréation de sets dans `token_overlap()`

`token_overlap()` crée `set(tokens_a)` et `set(tokens_b)` à chaque appel. Avec le clustering O(n²), cette opération se répète N² fois pour les mêmes listes.

**Fix attendu** : pré-calculer les sets une fois par n-gram avant le clustering.

### 3. N-gram index trop large (Step 1)

Tous les n-grams de longueur 3-6 sont indexés, même ceux qui n'apparaîtront qu'une seule fois. L'indexation puis le filtrage (Step 2) est moins efficace que filtrer pendant l'indexation.

**Fix attendu** : utiliser un `Counter` d'abord sur les n-grams, puis ne garder que ceux >= min_count avant de construire la liste d'occurrences complète.

## Approche de clustering recommandée

Remplacer l'O(n²) Jaccard par un clustering basé sur sorted-token signature :

```python
# Pré-calculer les sets de tokens pour chaque n-gram
ngram_token_sets = {ng: frozenset(ng) for ng, _ in kept_ngrams}

# Grouper par signature = frozenset des tokens communs les plus fréquents
# Deux n-grams dans le même bucket s'il partagent >= 60% de tokens
def ngram_signature(ngram_tuple):
    tokens = sorted(ngram_tuple)
    # Garder les 60% les plus longs comme clé de signature
    n = max(1, int(len(tokens) * 0.6))
    return tuple(tokens[:n])

from collections import defaultdict
buckets = defaultdict(list)
for i, (ng, occ) in enumerate(kept_ngrams):
    sig = ngram_signature(ng)
    buckets[sig].append(i)

# Chaque bucket est un cluster candidat
# Vérification optionnelle Jaccard à l'intérieur du bucket seulement
```

Cette approche est O(N) pour le bucketing, O(k²) pour la vérification intra-bucket où k est petit.

## Contraintes absolues

1. Les patterns en output doivent rester pertinents — pas de régression qualitative
2. L'output doit avoir >= 3 patterns pour 30 jours d'historique
3. Zéro dépendance externe (stdlib only)
4. La structure de chaque suggestion doit garder les mêmes champs : `pattern`, `count`, `session_count`, `project_count`, `cross_project`, `category`, `score`, `example_sessions`

## Validation

```bash
# Baseline (avec cache froid)
rm -f ~/.claude/discover-cache.jsonl
time python3 cc-sessions --all discover --since 30d --min-count 2

# Après optimisation
rm -f ~/.claude/discover-cache.jsonl
bash scripts/runner-discover.sh

# Vérification qualitative : les patterns doivent être lisibles et pertinents
python3 cc-sessions --all discover --since 30d --min-count 2 | head -30
```
