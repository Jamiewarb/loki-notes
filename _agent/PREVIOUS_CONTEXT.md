# Previous context — Loci agents

Handoff notes updated after each stacked PR. Read this before starting the next PR.

---

## PR17 — Tags

**Branch:** `cursor/pr17-tags-d2c1`  
**Based on:** `cursor/pr16-wikilinks-d2c1` @ `ef6dd39`

### What landed

- **Object-level tags** in YAML frontmatter (inspector `ObjectTagsEditorView`) + body `#tag` via editor completer
- **`TagTriggerDetector` / `EditorSession.insertTag`** — `#` completer mirrors `@` / `[[` picker
- **`IndexQuerying`:** `allTags`, `objects(tagged:)`, `tagCandidates` (+ `TagsQuery`)
- **`TagNormalization` / `TagAliasTable` / `TagFilter`** in Core; aliases on `SpaceSettings.tagAliases`
- **`Features/Tags/`:** `TagBrowseView`, `TagCompleterView`, `ObjectTagsEditorView`, `TagsFeature`
- **Route.tags** (Studio) + type-dashboard **filter by #tag**
- **Demo:** `loci-tags-demo` / `scripts/demo-tags.sh` → `DevHarness/public/demo-tags/`
- **Harness:** Studio → Tags (`?panel=tags`)
- **Tests:** **152** package tests (was 139)
- Evidence: `evidence/pr17/`
- Version: Index / Markdown → `*-pr17`; Vault → `0.17.0-pr17`
- **AST `#tag` case preserved** in markdown; index lowercases via `TagNormalization`

### How to run checks

```bash
export PATH=/opt/swift/usr/bin:$PATH
./scripts/lint.sh
./scripts/test.sh
./scripts/demo-tags.sh
./scripts/run-harness.sh   # http://127.0.0.1:5173/?panel=tags
```

### Pitfalls for PR18 (search)

- FTS already exists (`blocks_fts` + `IndexQuerying.search`) — PR18 is ⌘K / Search UI polish
- Do not block typing on index; search reads `IndexQuerying` only
- Do not put SQLite / index inside the vault
- Tag browse is Studio (`Route.tags`); Search remains primary for FTS
- Alias expansion lives on queries, not rewritten into markdown

### Next: PR18 — Global search

- Branch: `cursor/pr18-search-d2c1`
- ⌘K / SearchView over existing FTS; filters; never blocks typing
- Depends on: PR07 (index FTS already present)

---

## PR16 — Wiki-links and backlinks

**Branch:** `cursor/pr16-wikilinks-d2c1`

LinkResolver, `@`/`[[` picker, backlinks panel. See `evidence/pr16/`.

### Still relevant

- Preferred wiki target = ObjectID
- Broken-link styling `is-broken` / `is-resolved`

---

## Wave A (PR01–PR08) complete · Wave B: PR09–PR17 done · next PR18
