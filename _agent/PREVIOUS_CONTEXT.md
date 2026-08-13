# Previous context — Loci agents

Handoff notes updated after each stacked PR. Read this before starting the next PR.

---

## Wave C (PR22–)

**Milestone:** Wave B MVP complete (PR09–PR21). Wave C depth: Collections → Queries → Graph…

Next stack: **PR24 Graph view**.

---

## PR23 — Saved queries + embeds

**Branch:** `cursor/pr23-queries-d2c1`  
**Based on:** `cursor/pr22-collections-d2c1` @ `d680d01`  
**Tip:** `dd4f13ed692f15c831fd04eac7ede99452bf1a34`

### What landed

- **QueryEngine** (`LociIndex/Queries/QueryEngine.swift`): DSL over index — type, tags (all/any), property ops (equals/contains/gt/…/exists), created/updated ranges, sort, limit
- **Core:** `QueryDefinition`, `SavedQuery`, `QueryID`; `IndexQuerying.execute`; `SchemaServing` query CRUD + pin; `LociError` query cases
- **Vault:** `.loci/queries/` in `VaultLayout`; `SchemaStore` definition JSON (`<slug>.json`) — **no live results in vault files**
- **Markdown:** `BlockNode.queryEmbed`; fence ```` ```query ```` round-trip; `/query` slash; HTML placeholder
- **Features/Queries/:** `QueriesFeature`, `QueryStore`, `PinnedQueriesView`, `QueryEmbedView`
- **Type dashboard:** pinned queries section (alongside collections)
- **Block editor:** live embed row (slug editable + results from index)
- **Demo:** `loci-queries-demo` / `scripts/demo-queries.sh` → `DevHarness/public/demo-queries/`
- **Harness:** Types panel Pinned queries + Editor `/query` embed section
- **Tests:** QueryEngine filters, vault CRUD, query fence/slash (+8 → **202** total)
- Evidence: `evidence/pr23/`
- Version: Index / Markdown → `*-pr23`; Vault → `0.23.0-pr23`

### How to run checks

```bash
export PATH=/opt/swift/usr/bin:$PATH
./scripts/lint.sh
./scripts/test.sh
./scripts/demo-queries.sh
./scripts/run-harness.sh   # http://127.0.0.1:5173/?panel=types
                           # http://127.0.0.1:5173/?panel=editor
```

### Pitfalls for PR24 (Graph)

- Graph reads **links table** via IndexQuerying — do not scrape markdown in the feature
- Performance cap required (node/edge limit); avoid O(n²) force layout on full vault
- No feature→feature imports; Graph talks Index + Navigating protocols only
- Collections/Queries dashboard chrome already share TypeDashboard — leave alone unless graph needs a type filter control of its own

### Next: PR24 — Graph view

- Branch: `cursor/pr24-graph-d2c1`
- Force-directed (or simple adjacency) graph from links table; filter by type; open object on node tap; basic performance cap
- Depends on: PR16

---

## PR22 — Collections

**Branch:** `cursor/pr22-collections-d2c1`

Manual collections per type; membership vault JSON. See `evidence/pr22/`.

### Still relevant

- Queries are rule-based / dynamic — do not confuse with manual collection membership files
- Query results are derived (index); `/query` embed stores slug only

---

## Wave A (PR01–PR08) · Wave B (PR09–PR21) **MVP complete** · Wave C PR22–PR23 done · next PR24
