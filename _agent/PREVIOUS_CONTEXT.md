# Previous context — Loci agents

Handoff notes updated after each stacked PR. Read this before starting the next PR.

---

## PR18 — Global FTS search

**Branch:** `cursor/pr18-search-d2c1`  
**Based on:** `cursor/pr17-tags-d2c1` @ `3fb51ef`

### What landed

- **`Features/Search/`:** `SearchFeature`, `SearchView` (destination + ⌘K), `SearchInspectorView` (recent queries)
- **Core:** `SearchGrouping` / `SearchRanking` / `RecentSearchStore` (`SearchModels.swift`) — Linux-tested
- **Index:** `SearchQuery.ftsMatchQuery` public; title+body FTS tests
- **App shell:** Search destination wired; macOS ⌘K → `openSearch()`; iOS Search tab focuses field
- **Demo:** `loci-search-demo` / `scripts/demo-search.sh` → `DevHarness/public/demo-search/`
- **Harness:** Search panel loads grouped FTS fixture (`?panel=search`)
- **Tests:** **159** package tests (was 152)
- Evidence: `evidence/pr18/`
- Version: Index / Markdown → `*-pr18`; Vault → `0.18.0-pr18`

### How to run checks

```bash
export PATH=/opt/swift/usr/bin:$PATH
./scripts/lint.sh
./scripts/test.sh
./scripts/demo-search.sh
# optional stress: LOCI_SEARCH_BULK=1000 ./scripts/demo-search.sh
./scripts/run-harness.sh   # http://127.0.0.1:5173/?panel=search
```

### Pitfalls for PR19 (tasks)

- Task list blocks already exist in markdown/editor AST — PR19 is aggregation + Today view
- Do not block typing on index; task toggles persist via ObjectServing.save
- Search reads `IndexQuerying` only; Tasks will need index projection for open tasks (may extend schema)
- Index never inside the vault

### Next: PR19 — Tasks

- Branch: `cursor/pr19-tasks-d2c1`
- Task completion toggles persist; Today / Open tasks from index; daily note side panel
- Depends on: PR09, PR07

---

## PR17 — Tags

**Branch:** `cursor/pr17-tags-d2c1`

Object-level + body `#tags`, aliases, TagBrowseView. See `evidence/pr17/`.

### Still relevant

- Alias expansion on queries, not rewritten into markdown
- Tag browse is Studio (`Route.tags`); Search is primary for FTS

---

## Wave A (PR01–PR08) complete · Wave B: PR09–PR18 done · next PR19
