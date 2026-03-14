Quick smoke test for cc-sessions commands.

```bash
echo "=== recent ===" && python3 cc-sessions recent 3
echo "=== search ===" && python3 cc-sessions search "test" --limit 3
echo "=== discover ===" && python3 cc-sessions --all discover --since 30d --top 5
```
