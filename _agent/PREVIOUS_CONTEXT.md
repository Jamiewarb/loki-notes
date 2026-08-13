# Previous context — Loci agents

Handoff notes updated after each stacked PR. Read this before starting the next PR.

---

## PR09 — Block editor MVP

**Branch:** `cursor/pr09-block-editor-d2c1`  
**Based on:** `cursor/pr08-object-crud-d2c1` @ `af741c6`

### What landed

- **`EditorSession` in `LociMarkdown`** (Linux-testable): owns BlockAST, `isDirty`, `revisionToken`; `applyLocalEdit`, `applySlashCommand`, `markSaved`, `proposeRemoteReload` (never clobbers if dirty), `serializeBody()`
- **`BlockEdit` / `SlashBlockKind`**: paragraph, h1–h4, bullet/numbered/task lists, quote, code; paste markdown; split/delete/toggle task
- **`BlockASTHTML`**: fixture HTML preview for harness
- **Apple UI** `App/Features/BlockEditor/`: `BlockEditorView`, `SlashMenuView`, `Keymap`, `EditorSessionBridge` (debounce 500ms + 5s max → `ObjectServing.save`)
- **`ObjectEditorView`**: title + BlockEditor (replaced plain TextEditor)
- **DevHarness Studio → Editor** (`?panel=editor`): slash simulation + AST HTML (tasks/headings/lists)
- **CLI:** `loci-editor-demo` + `scripts/demo-editor.sh`
- **Tests:** **84** package tests (was 78)
- Evidence: `evidence/pr09/`

### How to run checks

```bash
export PATH=/opt/swift/usr/bin:$PATH
./scripts/lint.sh
./scripts/test.sh
./scripts/demo-editor.sh
./scripts/run-harness.sh   # http://127.0.0.1:5173/?panel=editor
```

### Pitfalls for PR10 (Daily notes)

- Daily feature folder: `Features/DailyNotes/{DailyNoteService,DailyNoteView,DaySwitcher}`
- Deterministic file `daily/YYYY-MM-DD.md` and stable id scheme (`daily-{yyyy-mm-dd}` per PLAN)
- Open/create today on launch (esp. iOS); sidebar Daily destination becomes live
- Reuse EditorSession for body — do not reintroduce TextEditor
- Created-today list is **PR11** (inspector only); do not auto-write derived lists into daily markdown
- Local vault fallback must work for daily create without iCloud

### Next: PR10 — Daily notes

- Branch: `cursor/pr10-daily-notes-d2c1`

---

## PR08 — Object CRUD end-to-end (Wave A complete)

**Branch:** `cursor/pr08-object-crud-d2c1`

`ObjectService` create/open/save/delete; AppServices wiring; Page list; debounced save design. See `evidence/pr08/`.

### Still relevant

- `ObjectServing.save(meta:bodyMarkdown:)` is the persist boundary after editor serialize
- Index updates async after vault write; never block typing
- Types → Page list navigates to object editor route

---

## Wave A (PR01–PR08) — complete · Wave B starts at PR09
