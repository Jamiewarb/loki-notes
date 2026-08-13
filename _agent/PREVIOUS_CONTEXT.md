# Previous context — Loci agents

Handoff notes updated after each stacked PR. Read this before starting the next PR.

---

## PR06 — MarkdownKit (current)

**Branch:** `cursor/pr06-markdown-kit-d2c1`  
**Based on:** `cursor/pr05-schema-domain-d2c1` @ `c3b85c9`

### What landed

- **`LociMarkdown` (real):**
  - `BlockNode` / `InlineNode` / `ListItem` / `LociDocument`
  - `FrontMatter` aligned with `LociObjectMeta` (`id`, `type`↔`typeID`, `title`, `created`, `updated`, `tags`, `properties`, optional `template`)
  - `MarkdownParser` + `MarkdownSerializer` with structural round-trip
  - `WikiLink` / `TagSyntax` helpers
  - **YAML choice:** hand-rolled `SimpleYAML` subset (no SPM YAML dependency; Linux-friendly). Documented on `LociMarkdownModule`.
  - `PropertyValueYAML` — bare primitives + tagged `{kind,value}` for select/url losslessness
- **Fixtures:** `LociMarkdown/Tests/LociMarkdownTests/Fixtures/*.md`
- **CLI:** `loci-markdown-demo` + `scripts/demo-markdown.sh` → `DevHarness/public/demo-markdown/`
- **DevHarness:** Studio nav **Markdown** panel (`?panel=markdown`) shows input/serialized round-trip
- **Tests:** **66** package tests (was 48) — 18 new MarkdownKit tests; Vault/Schema unchanged green
- Evidence: `evidence/pr06/`

### Supported block types

| Block | Notes |
|---|---|
| paragraph | inline: text, code, emphasis, strong, link, image, wiki-link, tag |
| heading 1–4 | `#`…`####` (h5+ stays paragraph text) |
| bulletList | `-` / `*` / `+` |
| numberedList | `1.` … |
| task items | `- [ ]` / `- [x]` on bullet lists |
| blockQuote | `>` lines |
| codeBlock | fenced ` ``` ` / `~~~` |
| image | standalone `![]()` block or inline |
| thematicBreak | `---` / `***` / `___` |
| wiki-link | `[[target]]` / `[[target\|label]]` |
| #tag | `#Focus`, nested `a/b` |

### How to run checks

```bash
export PATH=/opt/swift/usr/bin:$PATH
./scripts/lint.sh
./scripts/test.sh
./scripts/demo-markdown.sh
./scripts/run-harness.sh   # http://127.0.0.1:5173/?panel=markdown
```

### Pitfalls for PR07 (Indexer)

- Parse vault `.md` with `MarkdownParser` → index `FrontMatter` + walk blocks for wiki-links / tags / task items / FTS text
- `WikiLinkSyntax.extract` / `TagSyntax.extract` available for flat scans; prefer AST walk for accuracy
- Frontmatter `type` key maps to `ObjectTypeID`; `relativePath` is **not** in frontmatter — Indexer/ObjectService must supply path
- Bare property arrays of `[[slug]]` decode as `.objectSelect` (brackets stripped); UUIDs in arrays also → objectSelect
- `.select` / `.url` serialize as tagged YAML maps so they round-trip; bare strings decode as `.text`
- **Never** put `index.sqlite` in the vault — Application Support only
- Indexer should depend on `LociCore` + `LociMarkdown`; apply vault events asynchronously

### Next: PR07 — Indexer (SQLite)

- GRDB/SQLite in Application Support; schema objects/links/tags/blocks_fts/properties_idx
- Full scan + incremental Vault events; `IndexQuerying` APIs
- Branch: `cursor/pr07-indexer-d2c1` (or plan name)

---

## PR05 — Domain models + schema store

**Branch:** `cursor/pr05-schema-domain-d2c1`  
**Based on:** `cursor/pr04-vault-io-d2c1` @ `944321d`

### What landed

- **LociCore models:** `ObjectType`, `PropertyDef`, `PropertyKind`, `TypeDashboardConfig`; expanded `PropertyValue` (select / multiSelect / objectSelect / url), `SpaceSettings.pins`, `LociObjectMeta.tags` + `properties`
- **`SchemaServing`:** load/save space, knownTypeIDs / loadType / saveType / allTypes / `bootstrapSchema`
- **`SchemaStore` (LociVault):** `.loci/space.json` + per-type `.loci/types/<slug>.json` (not monolithic schema.json); seeds built-in **Page**
- **`VaultService.ensureSkeleton`:** also writes `page.json` when missing (idempotent)
- **App:** `AppServices.schema`; `TypeListView` (read-only); Settings create vault → `bootstrapSchema`
- **CLI / harness:** `scripts/demo-schema.sh` → `DevHarness/public/demo-schema/`; Types panel `?panel=types`
- **Tests:** **48** package tests (was 30) — domain Codable + SchemaStore bootstrap / custom type reload
- Evidence: `evidence/pr05/`

### Schema file shapes

**`.loci/space.json`**
```json
{ "name": "Loci", "schemaVersion": 1, "pins": [] }
```

**`.loci/types/page.json`**
```json
{
  "id": "page",
  "name": "Page",
  "icon": "doc.text",
  "color": "#0F6B5C",
  "properties": [],
  "templateIDs": [],
  "dashboard": { "cardPreviewPropertyIDs": [] },
  "isBuiltIn": true,
  "isDaily": false
}
```

---

## PR04 — VaultIO + iCloud Documents

**Branch:** `cursor/pr04-vault-io-d2c1`

See prior handoff for VaultServing API, skeleton layout, trash/tombstones.

---

## PR03 / PR02 / PR01

App shell, design system (editorial-sage), SPM scaffold. Swift **6.2** at `/opt/swift`.
