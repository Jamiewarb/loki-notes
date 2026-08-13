# PR28 evidence

| Check | Result |
|---|---|
| `./scripts/lint.sh` | passed (`evidence/pr28/lint.log`) |
| `./scripts/test.sh` | **258** tests, 0 failures (`evidence/pr28/test.log`) — was 250 on PR27 |
| `./scripts/demo-type-convert.sh` | passed — 12/12 proof (`evidence/pr28/demo.log`, `type-convert.json`) |
| DevHarness `?panel=type-convert` | HTML + screenshot (`harness.html`, `harness-dom.html`, `harness.png`) |

## What landed

- `ObjectServing.planConversion` / `convert` — remap PropertyDefs, move under `objects/<type>/`, keep ObjectID, reindex via IndexUpdating
- `VaultServing.moveFile` for coordinated relocate; convert writes rewritten frontmatter then deletes old path
- Pure `TypeConversionMapper` (suggest + coerce + drop / required checks)
- `Features/TypeConversion/` panel + sheet (editor / inspector); no feature→feature imports
- DevHarness Convert panel + `loci-type-convert-demo` / `scripts/demo-type-convert.sh`
- Daily notes and same-type conversions refused (`LociError.typeConversionNotAllowed`)
- Versions: Vault `0.28.0-pr28`; Index / Markdown `0.2.0-pr28`

## Demo

```bash
./scripts/demo-type-convert.sh
# http://127.0.0.1:5173/?panel=type-convert
```
