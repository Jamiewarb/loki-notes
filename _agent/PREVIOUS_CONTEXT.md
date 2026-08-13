# Previous context — Loci agents

Handoff notes updated after each stacked PR. Read this before starting the next PR.

---

## PR16 — Wiki-links and backlinks

**Branch:** `cursor/pr16-wikilinks-d2c1`  
**Based on:** `cursor/pr15-para-d2c1` @ `7a9367c`

### What landed

- **`LinkResolver`** (Index): ObjectID → path/slug → title; `preferredTarget` = ObjectID
- **`IndexQuerying`:** `resolve`, `backlinks(to:)`, `outgoingLinks(from:)`, `linkCandidates`
- **`@` / `[[` picker** in BlockEditor → inserts `[[id|title]]`; Linux-testable `EditorSession.insertWikiLink`
- **`Features/Links/`:** `LinkPickerView`, `BacklinksPanel`, `WikiLinkStatusView`
- **Inspector:** object route shows Properties + Backlinks
- **Broken-link styling:** `wiki-link is-broken` (danger + dash) vs `is-resolved` (accent)
- **Demo:** `loci-links-demo` / `scripts/demo-links.sh` → `DevHarness/public/demo-links/`
- **Harness:** Studio → Links (`?panel=links`)
- **Tests:** **139** package tests (was 127)
- Evidence: `evidence/pr16/`
- Version: Index / Markdown / Vault → `*-pr16`
- **Skipped:** Project `area` object-select promotion (optional; avoid scope creep)

### How to run checks

```bash
export PATH=/opt/swift/usr/bin:$PATH
./scripts/lint.sh
./scripts/test.sh
./scripts/demo-links.sh
./scripts/run-harness.sh   # http://127.0.0.1:5173/?panel=links
```

### Pitfalls for PR17 (tags)

- `#tag` already in Loci MD AST + `tags` index table — UI/browse/aliases next
- Object-level tags live in frontmatter; body `#tags` also indexed
- Do not auto-write derived tag lists into markdown
- Do not put SQLite / index inside the vault
- Template ids remain `<type>.<slug>`

### Next: PR17 — Tags

- Branch: `cursor/pr17-tags-d2c1`
- `#tag` in editor + object-level tags; tag index browse; aliases; dashboard filter
- Demo: tag two types with `#health`; tag page lists both

---

## PR15 — PARA starter pack

**Branch:** `cursor/pr15-para-d2c1`

PARA Project/Area pack, `#resource` / `#archive`, ArchiveFilter. See `evidence/pr15/`.

### Still relevant

- Project `area` property remains **text** — can become object-select using LinkResolver
- Resource = tag approach; Archive = tag/status filter (no folder move)

---

## Wave A (PR01–PR08) complete · Wave B: PR09–PR16 done · next PR17
