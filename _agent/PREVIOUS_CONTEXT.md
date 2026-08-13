# Previous context — Loci agents

Handoff notes updated after each stacked PR. Read this before starting the next PR.

---

## Wave C (PR22–)

**Milestone:** Wave B MVP complete (PR09–PR21). Wave C depth: Collections → Queries → Graph → Calendar…

Next stack: **PR25 Calendar UI**.

---

## PR24 — Graph view

**Branch:** `cursor/pr24-graph-d2c1`  
**Based on:** `cursor/pr23-queries-d2c1` @ `a2ad141`  
**Tip:** `0ac596db9fb1a043f7dd5c4a176dd3d38c953d94`

### What landed

- **Core:** `GraphNode` / `GraphEdge` / `GraphSnapshot` / `GraphBuildOptions`; `GraphAssembly` (type filter + degree caps); `GraphLayoutEngine` (deterministic force-directed, Linux-testable)
- **Index:** `IndexQuerying.graph`; `GraphBuilder` over `links` table + `LinkResolver` (broken links counted, not drawn)
- **Route.graph** + AppShell Studio wiring (sidebar / iOS Settings stack / inspector)
- **Features/Graph/:** `GraphFeature`, `GraphStore`, `GraphView` (Canvas), `GraphInspectorView` — node tap → `Navigating.open`
- **Demo:** `loci-graph-demo` / `scripts/demo-graph.sh` → `DevHarness/public/demo-graph/`
- **Harness:** Studio **Graph** panel (SVG) at `?panel=graph`
- **Tests:** GraphAssembly caps/filter + layout determinism + GraphBuilder index tests (+9 → **211** total)
- Evidence: `evidence/pr24/`
- Version: Index / Markdown → `*-pr24`; Vault → `0.24.0-pr24`

### How to run checks

```bash
export PATH=/opt/swift/usr/bin:$PATH
./scripts/lint.sh
./scripts/test.sh
./scripts/demo-graph.sh
./scripts/run-harness.sh   # http://127.0.0.1:5173/?panel=graph
```

### Pitfalls for PR25 (Calendar)

- Calendar must use **deterministic daily paths** (`daily/YYYY-MM-DD.md`) + `IndexQuerying.created(on:)` / daily identity — do not invent parallel date indexes in the vault
- Dots for “has content / creations” are **index-derived UI only**; never rewrite daily markdown for calendar chrome
- No feature→feature imports; Calendar talks DailyNoteServing / Index / Navigating protocols
- Graph Studio destination already occupies tooling nav — leave alone unless calendar needs its own route

### Next: PR25 — Calendar UI

- Branch: `cursor/pr25-calendar-d2c1`
- Month/week calendar anchored to daily notes; dots for days with content/creations; jump to daily
- Depends on: PR10, PR11

---

## PR23 — Saved queries + embeds

**Branch:** `cursor/pr23-queries-d2c1`

QueryEngine DSL; `.loci/queries/`; `/query` embeds. See `evidence/pr23/`.

### Still relevant

- Graph must not scrape markdown — links table only (done in PR24)
- Query results remain derived; do not confuse with graph topology

---

## PR22 — Collections

Manual collections per type; membership vault JSON. See `evidence/pr22/`.

---

## Wave A (PR01–PR08) · Wave B (PR09–PR21) **MVP complete** · Wave C PR22–PR24 done · next PR25
