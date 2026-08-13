# Previous context — Loci agents

Handoff notes updated after each stacked PR. Read this before starting the next PR.

---

## PR19 — Tasks

**Branch:** `cursor/pr19-tasks-d2c1`  
**Based on:** `cursor/pr18-search-d2c1` @ `3b1cda6`

### What landed

- **`Features/Tasks/`:** `TasksFeature`, `TasksView` (Today / Open), `OpenTasksPanel` (daily inspector)
- **Core:** `IndexedTask`, `TaskAggregation`, `Route.tasks` (primary nav), `IndexQuerying` task APIs
- **Index:** `tasks` table (migration `v2-tasks`), ObjectIndexer extracts GFM checkboxes, `TasksQuery`
- **Markdown:** `TaskBodyEdits.toggle` for aggregation-view checkbox → `ObjectServing.save`
- **Editor:** existing `/task` + checkbox still debounce-save via `EditorSessionBridge` (unchanged path)
- **Demo:** `loci-tasks-demo` / `scripts/demo-tasks.sh` → `DevHarness/public/demo-tasks/`
- **Harness:** Tasks panel (`?panel=tasks`); daily inspector also shows open tasks from fixture
- **Tests:** **163** package tests (was 159)
- Evidence: `evidence/pr19/`
- Version: Index / Markdown → `*-pr19`; Vault → `0.19.0-pr19`

### How to run checks

```bash
export PATH=/opt/swift/usr/bin:$PATH
./scripts/lint.sh
./scripts/test.sh
./scripts/demo-tasks.sh
./scripts/run-harness.sh   # http://127.0.0.1:5173/?panel=tasks
```

### Pitfalls for PR20 (media)

- Task rows key off `blockIndex|itemIndex` — fine for aggregation; renames/reorders can orphan UI toggles until reload
- Do not put media binaries or thumbnails in the SQLite index; vault `media/` is truth
- Index never inside the vault
- Features must not import each other (Media ↔ Tasks via protocols only)

### Next: PR20 — Media

- Branch: `cursor/pr20-media-d2c1`
- Attach image/file → `media/`; markdown image syntax; Image object type; drag-drop / photos picker
- Depends on: PR08, PR09

---

## PR18 — Global FTS search

**Branch:** `cursor/pr18-search-d2c1`

Global FTS SearchView + grouping. See `evidence/pr18/`.

### Still relevant

- Search reads `IndexQuerying` only; never blocks typing
- FTS lives in Application Support

---

## Wave A (PR01–PR08) complete · Wave B: PR09–PR19 done · next PR20
