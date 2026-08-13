# PR27 evidence

| Check | Result |
|---|---|
| `./scripts/lint.sh` | passed (`evidence/pr27/lint.log`) |
| `./scripts/test.sh` | **250** tests, 0 failures (`evidence/pr27/test.log`) — was 232 on PR26 |
| `./scripts/demo-import.sh` | passed — 14/14 proof (`evidence/pr27/demo.log`, `import.json`) |
| DevHarness `?panel=import` | HTML + screenshot (`harness.html`, `harness-dom.html`, `harness.png`) |

## What landed

- Importers: markdown folder, Obsidian vault, Capacities-style export
- Dry-run summary before apply; conflict policies skip / rename / overwrite
- Preserves ObjectID + `daily/YYYY-MM-DD.md` / `daily-YYYY-MM-DD` when detectable
- `Features/ImportExport/`, `ImportServing`, fixtures under `LociVault/Tests/LociVaultTests/Fixtures/import/`
- Versions: Vault `0.27.0-pr27`; Index / Markdown `0.2.0-pr27`

## Demo

```bash
./scripts/demo-import.sh
# http://127.0.0.1:5173/?panel=import
```
