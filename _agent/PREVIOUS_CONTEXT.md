# Previous context — Loci agents

Handoff notes updated after each stacked PR. Read this before starting the next PR.

---

## PR07 — Indexer (current)

**Branch:** `cursor/pr07-indexer-d2c1`  
**Based on:** `cursor/pr06-markdown-kit-d2c1` @ `95472f9`

### What landed

- **`LociIndex` (real):**
  - **GRDB** SQLite (Linux + Apple); FTS5 `blocks_fts`
  - `IndexDatabase(vaultID:directory:)` → `<directory>/<vaultID>/index.sqlite` (**never vault**)
  - Tables: `objects`, `links`, `tags`, `blocks_fts`, `properties_idx`
  - `IndexService`: `IndexQuerying` + `IndexUpdating` (full `rebuild` + incremental vault events)
  - Writers: `ObjectIndexer` (MarkdownParser AST walk), `LinkIndexer`
  - Queries: `SearchQuery`, `CreatedOnQuery`
- **CLI:** `loci-index-demo` + `scripts/demo-index.sh` → `DevHarness/public/demo-index/search.json`
- **DevHarness:** Search panel (`?panel=search`) shows FTS hits + created(on:) + “index inside vault? no”
- **App:** `AppServices.ensureIndex()` wires Application Support index (ready for PR08)
- **Tests:** **73** package tests (was 66)
- Evidence: `evidence/pr07/` — NOTES confirm no `index.sqlite` under vault

### How to run checks

```bash
export PATH=/opt/swift/usr/bin:$PATH
./scripts/lint.sh
./scripts/test.sh
./scripts/demo-index.sh
./scripts/run-harness.sh   # http://127.0.0.1:5173/?panel=search
```

### Pitfalls for PR08 (Object CRUD)

- `ObjectServing` should: allocate path under `objects/<type>/`, write markdown via `MarkdownSerializer` + `VaultServing`, then `IndexUpdating.applyVaultEvent` (async — do not block typing)
- List Pages via `IndexQuerying.objects(typeID: .page)` (not directory scrape alone)
- Delete = `VaultServing.trashFile` + index `.deleted` event; respect tombstones
- Open by id: `IndexQuerying.object(id:)` → `relativePath` → vault read → parse
- Debounced save: editor owns dirty state; index is stale-while-revalidate
- `AppServices.index` may be nil until `ensureIndex()` — call after vault create/open
- Frontmatter `type` maps to `ObjectTypeID`; path is **not** in frontmatter — ObjectService supplies it
- Do **not** put SQLite in the vault; use `IndexDatabase` / `ensureIndex()` only

### Next: PR08 — Object CRUD end-to-end

- `ObjectService`; Create Page → `objects/page/` → open → edit title → debounced save
- List Pages; delete → trash+tombstone; AppShell “New Page”
- Branch: `cursor/pr08-object-crud-d2c1` (or plan name)

---

## PR06 — MarkdownKit

**Branch:** `cursor/pr06-markdown-kit-d2c1`  
**Based on:** `cursor/pr05-schema-domain-d2c1` @ `c3b85c9`

### What landed

- **`LociMarkdown`:** BlockAST, FrontMatter, parser/serializer, SimpleYAML, wiki-links/tags
- Fixtures + `loci-markdown-demo` + Markdown harness panel
- **66** tests at merge tip used by PR07

### Pitfalls (still relevant)

- Prefer AST walk for links/tags (Indexer does this)
- Bare property arrays of `[[slug]]` decode as `.objectSelect`
- `.select` / `.url` serialize as tagged YAML maps

---

## PR05 — Domain models + schema store

**Branch:** `cursor/pr05-schema-domain-d2c1`

See prior handoff for SchemaStore / per-type `.loci/types/*.json`.

---

## PR04 / PR03 / PR02 / PR01

VaultIO, app shell, design system, SPM scaffold. Swift **6.2** at `/opt/swift`.
