# Previous context — Loci agents

Handoff notes updated after each stacked PR. Read this before starting the next PR.

---

## Wave C start (PR22+)

**Milestone:** Wave B MVP complete (PR09–PR21). Wave C depth begins at Collections.

Next stack: **PR23 Saved queries + embeds**.

---

## PR22 — Collections

**Branch:** `cursor/pr22-collections-d2c1`  
**Based on:** `cursor/pr21-sync-ux-d2c1` @ `8970e4d`  
**Tip:**  (evidence at )

### What landed

- **`Features/Collections/`:** `CollectionsFeature`, `CollectionStore`, `CollectionTabsView`
- **Core:** `ObjectCollection`, `CollectionID`; `SchemaServing` collection CRUD + add/remove; `LociError` collection cases
- **Vault:** `.loci/collections/` in `VaultLayout`; `SchemaStore` membership JSON (`<type>.<slug>.json`); merge-friendly per-file truth
- **Type dashboard:** All / collection tabs; create/delete collection; add/remove objects (ordered membership)
- **Demo:** `loci-collections-demo` / `scripts/demo-collections.sh` → `DevHarness/public/demo-collections/`
- **Harness:** Types panel collection tabs + Collections section (`?panel=types`)
- **Tests:** collection CRUD, membership order, skeleton dir, Core Codable (+5 → **194** total)
- Evidence: `evidence/pr22/`
- Version: Index / Markdown → `*-pr22`; Vault → `0.22.0-pr22`

### How to run checks

```bash
export PATH=/opt/swift/usr/bin:$PATH
./scripts/lint.sh
./scripts/test.sh
./scripts/demo-collections.sh
./scripts/run-harness.sh   # http://127.0.0.1:5173/?panel=types
```

### Pitfalls for PR23 (Queries)

- Queries are rule-based / dynamic — do not confuse with manual collection membership files
- Query results are derived (index); do not write live results into markdown unless user inserts `/query` embed
- QueryEngine belongs with Index (filter DSL); Features/Queries talks protocols only
- Embed blocks need Markdown kit + editor slash — keep Collections untouched
- Pin-to-dashboard may share type-dashboard chrome with collection tabs — extend carefully, no feature→feature imports beyond existing TypeDashboard composition pattern

### Next: PR23 — Saved queries + embeds

- Branch: `cursor/pr23-queries-d2c1`
- QueryEngine DSL (type, tags, property ops, created/updated ranges); save query objects; pin to dashboard; `/query` embed
- Depends on: PR13

---

## PR21 — Sync UX and resilience

**Branch:** `cursor/pr21-sync-ux-d2c1`

Sync chip, conflicts, ensure-downloaded, rebuild index. See `evidence/pr21/`.

### Still relevant

- Collections membership is vault JSON; Sync conflict scanner may later list `.loci/collections/*.json` conflicted copies (not required in PR22)

---

## Wave A (PR01–PR08) · Wave B (PR09–PR21) **MVP complete** · Wave C PR22 done · next PR23
