# PR13 — Properties system

## Summary

Property definitions live on types (`.loci/types/<slug>.json`). Object values live in YAML frontmatter and are edited in the inspector. Saves update disposable `properties_idx` for later filter/sort.

## Demo proof

| Check | Result |
|---|---|
| Book defs `status` + `rating` (+ url, finished) | in `book.json` / harness |
| Deep Work `status=Reading`, `rating=5` | YAML frontmatter |
| Survive reload | `survivedReload=true` |
| `properties_idx` | `statusIndexed`, `ratingIndexed` |
| Filter `status=Reading` | count=1 |
| Index outside vault | `indexInsideVault=false` |

## What landed

| Piece | Location |
|---|---|
| `PropertyKey`, `PropertyValueFormatting` | `LociCore` |
| Schema property CRUD | `SchemaServing` + `SchemaStore` |
| Index filter + rows | `IndexQuerying` + `PropertiesQuery` |
| UI | `Features/Properties/{PropertyEditor,PropertyDefsEditor,PropertyDraft}` |
| Inspector wiring | object → values; type focus → defs |
| Editor session | `applyProperties` shares save with inspector |
| Demo | `loci-properties-demo` + `scripts/demo-properties.sh` |
| Harness | Types panel object detail + inspector props |
| Version | `LociVaultModule` / `LociIndexModule` → pr13 |

## Tests

- **111** package tests (was 105)
- Lint + build green

## Harness

- `http://127.0.0.1:5173/?panel=types`
- Shows Book property defs, Deep Work values, frontmatter snippet, idx proof
- Artifacts: `harness-types.png`, `harness-types-dom.html`, `properties.json`

## Notes for PR14 (Templates)

- Property defs + values are ready — templates can prefills default property values
- Apply template on create should merge into `LociObjectMeta.properties`
- Store under `.loci/templates/` or schema `defaultTemplateID`
- Do not rewrite type id/slug when applying templates
