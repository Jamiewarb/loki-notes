# PR08 — Object CRUD evidence notes

## Summary

**Wave A complete.** `ObjectService` implements `ObjectServing`: create Page under `objects/page/`, open/parse, save (title/body), delete (trash+tombstone+index). Wired through `AppServices` + ObjectEditor host + Types/Page list. DevHarness Types panel lists pages from `demo-objects/pages.json`.

## Write path

```text
Feature → ObjectServing.save/create
       → MarkdownSerializer + VaultServing.write
       → IndexUpdating.applyVaultEvent (async after vault success)
```

Debounce lives in `ObjectEditorSession` (500ms). Service save is immediate once called.

## Tests

- **78** package tests (was 73)
- `ObjectServiceTests.testCreateIndexListOpenSaveDeleteLoop` proves full loop
- Lint + build green
- Demo JSON: `"indexInsideVault": false`, 2 pages listed

## Harness

- `http://127.0.0.1:5173/?panel=types`
- Pages section shows Hello Loci + Second Note; detail placeholder on click
- Artifacts: `harness-types.png`, `harness-types-dom.html`, `pages.json`

## Artifacts

| File | Meaning |
|---|---|
| `test.log` | `./scripts/test.sh` |
| `lint.log` | `./scripts/lint.sh` |
| `demo-objects.log` | `./scripts/demo-objects.sh` |
| `pages.json` | ObjectService export fixture |
| `harness-types.png` | Types/Page panel screenshot |
| `harness-types-dom.html` | rendered DOM |
| `harness.log` | Vite server log |

## Notes for PR09

- Swap TextEditor for BlockAST editor; keep ObjectServing boundary
- EditorSession single writer; proposeRemoteReload if dirty
- Do not block typing on index rebuild
