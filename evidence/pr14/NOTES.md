# PR14 — Templates

## Summary

Per-type templates store body markdown + default property values under `.loci/templates/<id>.md`. Star one as default; `ObjectService.create` and `DailyNoteService` apply it on create.

## Demo proof

| Check | Result |
|---|---|
| Book default `book.default` | `.loci/templates/book.default.md` |
| Prefills `## Summary` / `## Quotes` / `## Notes` | `bookPrefill=true` |
| Default props `status=To Read`, `rating=0` | in Deep Work frontmatter |
| Daily `daily.default` → `## Morning` / `## Evening` | `dailyPrefill=true` |
| Index outside vault | `indexInsideVault=false` |

## What landed

| Piece | Location |
|---|---|
| `ObjectTemplate`, `TemplateID` | `LociCore` |
| `TemplateCodec` | `LociMarkdown` |
| Schema template CRUD + star | `SchemaServing` + `SchemaStore` |
| Apply on create | `ObjectService`, `DailyNoteService` |
| `applyTemplateIfEmpty` | `ObjectServing` |
| UI | `Features/Templates/{TemplateStore,TemplateEditor,TemplatePicker,TemplateDraft}` |
| Demo | `loci-templates-demo` + `scripts/demo-templates.sh` |
| Harness | Types panel body + daily template + inspector |
| Version | `LociVaultModule` / `LociIndexModule` → pr14 |

## Tests

- **120** package tests (was 111)
- Lint + build green

## Harness

- `http://127.0.0.1:5173/?panel=types`
- Shows Book template body, Deep Work prefilled headings, daily template body, inspector defaults
- Artifacts: `harness-types.png`, `harness-types-dom.html`, `templates.json`

## Notes for PR15 (PARA)

- Templates + properties ready for Project/Area starter pack
- Apply PARA → create types with starter properties/templates via `SchemaServing`
- Archive via `#archive` or status + sidebar filters (not folder moves)
- Do not put SQLite / index inside the vault
