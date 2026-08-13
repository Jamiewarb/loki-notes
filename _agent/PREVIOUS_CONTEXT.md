# Previous context — Loci agents

Handoff notes updated after each stacked PR. Read this before starting the next PR.

---

## Wave C (PR22–)

**Milestone:** Wave B MVP complete (PR09–PR21). Wave C depth: Collections → Queries → Graph → Calendar → Capture → Import → TypeConvert…

Next stack: **PR28 Type conversion**.

---

## PR27 — Import

**Branch:** `cursor/pr27-import-d2c1`  
**Based on:** `cursor/pr26-share-widget-d2c1`  
**Tip:** *(see `git rev-parse HEAD` on branch after final commit)*

### What landed

- **Core:** `ImportSourceKind` / `ImportConflictPolicy` / `ImportPlanItem` / `ImportDryRunSummary` / `ImportApplyResult`; `ImportPathRules` / `ImportWikiLinkRewriter` / `ImportSourceDetector`; `ImportServing`; `Route.importExport`
- **Markdown:** `ImportDocumentProbe` + `ObsidianEmbedRewriter` (lenient foreign frontmatter)
- **Vault:** `ImportService` + `ImportSourceScanner`; module `0.27.0-pr27`
- **Features/ImportExport/:** dry-run-oriented panel + store; AppServices wires `ImportService`
- **Fixtures:** `Tests/LociVaultTests/Fixtures/import/{markdown-folder,obsidian-vault,capacities-export}`
- **Demo:** `loci-import-demo` / `scripts/demo-import.sh` → `DevHarness/public/demo-import/`
- **Harness:** Studio **Import** panel at `?panel=import`
- **Tests:** ImportModels (+6) + ImportDocumentProbe (+4) + ImportSystem (+8) + Route.importExport
- Evidence: `evidence/pr27/`
- Version: Index / Markdown → `*-pr27`; Vault → `0.27.0-pr27`

### How to run checks

```bash
export PATH=/opt/swift/usr/bin:$PATH
./scripts/lint.sh
./scripts/test.sh
./scripts/demo-import.sh
./scripts/run-harness.sh   # http://127.0.0.1:5173/?panel=import
```

### Pitfalls for PR28 (Type conversion)

- Type convert must **move** the markdown file between `objects/<type>/` folders — vault is truth
- Property mapping UI should reuse PropertyDef / PropertyValue; do not invent a second schema
- Update index links after path/type change via ObjectServing (or extend it) — never write SQLite from the feature
- Preserve ObjectID across conversion; only typeID + relativePath + mapped properties change
- No feature→feature imports; TypeConversion talks ObjectServing / SchemaServing / IndexUpdating

### Next: PR28 — Type conversion

- Branch: `cursor/pr28-type-convert-d2c1` (or `cursor/pr28-type-convert-…` per agent suffix)
- Change object type with property mapping UI; move file between `types/` folders; update index/links
- Depends on: PR13

---

## PR26 — Capture surfaces

**Branch:** `cursor/pr26-share-widget-d2c1`

Capture inbox → daily / typed object. See `evidence/pr26/`.

### Still relevant

- Import writes vault files like capture does — always index via applyVaultEvent / ObjectServing
- Do not confuse capture staging (`.loci/inbox/`) with import source trees (external folders)

---

## PR25 — Calendar UI

Calendar from index markers; day jump via DailyNoteServing. See `evidence/pr25/`.

---

## Wave A (PR01–PR08) · Wave B (PR09–PR21) **MVP complete** · Wave C PR22–PR27 done · next PR28
