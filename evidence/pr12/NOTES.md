# PR12 — Custom object types + dashboards

## Summary

Custom types are created on the fly via `SchemaServing.createType` → `.loci/types/<slug>.json` + `objects/<slug>/`. Type list + dashboard (All + recently-opened stub) live under `Features/ObjectTypes/`. Built-in Page/Daily cannot be deleted casually.

## Demo proof

| Check | Result |
|---|---|
| Create Books type | `.loci/types/book.json`, empty `properties` |
| `objects/book/` folder | exists |
| Create “Deep Work” | `objects/book/deep-work.md` |
| Index isolation | `booksCount=1`, `pagesCount=0`, `appearsOnlyUnderBooks=true` |
| Page delete guard | `pageDeleteBlocked=true` |

## What landed

| Piece | Location |
|---|---|
| `TypeSlug` | `LociCore/Models/TypeSlug.swift` |
| Schema CRUD | `SchemaServing` + `SchemaStore` create/rename/delete |
| Errors | `typeAlreadyExists`, `typeProtected`, `invalidTypeSlug`, `typeNotEmpty` |
| UI | `TypeListView`, `TypeEditorView`, `TypeDashboardView` |
| Sidebar | Types section lists schema types → dashboard |
| Demo | `loci-types-demo` + `scripts/demo-types.sh` |
| Harness | Types panel Books dashboard from `demo-types/` |
| Version | `LociVaultModule` → `0.12.0-pr12` |

## Tests

- **105** package tests (was 97)
- Lint + build green

## Harness

- `http://127.0.0.1:5173/?panel=types`
- Shows Books + Deep Work; Page delete guarded; only-under-Books proof
- Artifacts: `harness-types.png`, `harness-types-dom.html`, `types.json`

## Notes for PR13 (Properties)

- Types already store `properties: [PropertyDef]` (empty OK)
- Wire property editor in inspector; persist values in YAML frontmatter
- Index property columns for filter/sort on type dashboards
- Do not change type slug on rename — id stays stable
