# Previous context — Loci agents

Handoff notes updated after each stacked PR. Read this before starting the next PR.

---

## PR08 — Object CRUD end-to-end (Wave A complete)

**Branch:** `cursor/pr08-object-crud-d2c1`  
**Based on:** `cursor/pr07-indexer-d2c1` @ `57d5c4c`

### What landed

- **`ObjectService` (`ObjectServing`)** in `LociVault`:
  - `create` → `objects/<type>/<slug-or-id>.md` via `ObjectPathAllocator` + `MarkdownSerializer` / frontmatter
  - `open` → index lookup → vault read → parse → `OpenedObject` (meta + bodyMarkdown)
  - `save` → vault write → `IndexUpdating.applyVaultEvent(.modified)`
  - `delete` → `trashFile` + tombstone (with objectID) → index `.deleted`
- **`AppServices`:** `objects`, `ensureIndex()`, `openVaultPipeline()` (skeleton + bootstrapSchema + ensureIndex/rebuild), `createPage()`
- **Apple UI:** `Features/ObjectEditor/` (session + TextEditor host + PageListView), Types → Page list, sidebar **New Page**, `Features/Onboarding/`
- **Debounced save:** `ObjectEditorSession` documents 500ms debounce; service save is immediate once invoked
- **CLI / harness:** `loci-objects-demo` + `scripts/demo-objects.sh` → `DevHarness/public/demo-objects/pages.json`; Types panel lists Pages + detail placeholder
- **Tests:** **78** package tests (was 73) — create→index→list→open→save→delete loop
- Evidence: `evidence/pr08/` — `indexInsideVault: false`

### How to run checks

```bash
export PATH=/opt/swift/usr/bin:$PATH
./scripts/lint.sh
./scripts/test.sh
./scripts/demo-objects.sh
./scripts/run-harness.sh   # http://127.0.0.1:5173/?panel=types
```

### Pitfalls for PR09 (Block Editor)

- Replace plain `TextEditor` body with BlockAST editor; keep `ObjectEditorSession` as host or migrate to full `EditorSession` (PLAN 13.5)
- Typing must never await index; keep debounce on UI side; `ObjectServing.save` after idle
- `open` returns body markdown string today — parse to BlockAST in editor; save should serialize blocks → bodyMarkdown (or extend `save` later)
- Slash menu / enter-split / paste markdown are PR09 scope — do not regress ObjectService paths
- Wiki-link picker is PR16; only insert raw `[[…]]` text if needed for fixtures
- Daily notes automation is PR10 — do not special-case `daily/` create here beyond existing type path rules

### Next: PR09 — Block editor MVP

- `Features/BlockEditor/{BlockEditorView,SlashMenu,EditorSession,Keymap}`
- Bind to BlockAST; autosave debounce to ObjectServing; macOS shortcuts
- Branch: `cursor/pr09-block-editor-d2c1`

---

## PR07 — Indexer

**Branch:** `cursor/pr07-indexer-d2c1`

GRDB SQLite in Application Support; `IndexService` query/update; FTS5; never in vault. See evidence/pr07.

### Still relevant

- List Pages via `IndexQuerying.objects(typeID: .page)`
- Index DB only via `ensureIndex()` / `IndexDatabase`
- Frontmatter `type` maps to `ObjectTypeID`; path is locator from ObjectService

---

## Wave A (PR01–PR08) — complete

Scaffold → design system → shell → vault I/O → schema → markdown → index → **object CRUD**. Unblocks Wave B product features.
