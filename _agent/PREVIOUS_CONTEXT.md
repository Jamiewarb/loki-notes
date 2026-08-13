# Previous context — Loci agents

Handoff notes updated after each stacked PR. Read this before starting the next PR.

---

## Wave C (PR22–)

**Milestone:** Wave B MVP complete (PR09–PR21). Wave C depth: Collections → Queries → Graph → Calendar → Capture → Import → TypeConvert → EditorRich…

Next stack: **PR29 Richer editor**.

---

## PR28 — Type conversion

**Branch:** `cursor/pr28-type-convert-d2c1`  
**Based on:** `cursor/pr27-import-d2c1` tip `34e3c2dda0`  
**Tip:** `b90dd4ef73df7295838dfa3c42a8151be4e8e2c1`

### What landed

- **Core:** `TypeConversionPropertyMap` / `TypeConversionPlan` / `TypeConversionResult` / `TypeConversionMapper`; `ObjectServing.planConversion` + `convert`; `VaultServing.moveFile`; `Route.typeConvert`; `LociError.typeConversionNotAllowed`
- **Vault:** `ObjectService` conversion (remap props → write new path → delete old → IndexUpdating deleted+created); module `0.28.0-pr28`
- **Features/TypeConversion/:** property-mapping UI (sheet + Studio panel); AppServices via ObjectServing / SchemaServing only
- **Demo:** `loci-type-convert-demo` / `scripts/demo-type-convert.sh` → `DevHarness/public/demo-type-convert/`
- **Harness:** Studio **Convert** panel at `?panel=type-convert`
- **Tests:** TypeConversionMapper (+3) + TypeConversionSystem (+5) + Route.typeConvert; version asserts accept pr28
- Evidence: `evidence/pr28/`
- Version: Index / Markdown → `0.2.0-pr28`; Vault → `0.28.0-pr28`

### How to run checks

```bash
export PATH=/opt/swift/usr/bin:$PATH
./scripts/lint.sh
./scripts/test.sh
./scripts/demo-type-convert.sh
./scripts/run-harness.sh   # http://127.0.0.1:5173/?panel=type-convert
```

### Pitfalls for PR29 (Richer editor)

- Tables / toggles / callouts / code highlight land in LociMarkdown BlockAST + BlockEditor — keep EditorSession serialize round-trip green
- Optional Mermaid: prefer WebKit render on Apple; Linux harness can stub
- Block-to-object conversion (“turn selection into Book”) should call ObjectServing.create + insert wiki-link — reuse type/templates, not a parallel writer
- Typing must never await index; debounced save stays in EditorSessionBridge
- No feature→feature imports (BlockEditor ↔ ObjectTypes via protocols / composition)

### Next: PR29 — Richer editor

- Branch: `cursor/pr29-editor-rich-d2c1` (or `cursor/pr29-editor-rich-…` per agent suffix)
- Simple tables, toggles/callouts, code syntax highlighting, Mermaid render (optional WebKit), block-to-object conversion
- Depends on: PR09

---

## PR27 — Import

**Branch:** `cursor/pr27-import-d2c1`

Import markdown / Obsidian / Capacities with dry-run. See `evidence/pr27/`.

### Still relevant

- Type convert writes vault like import/capture — always index via applyVaultEvent / ObjectServing
- Preserve ObjectID across moves; path is locator only

---

## PR26 — Capture surfaces

Capture inbox → daily / typed object. See `evidence/pr26/`.

---

## Wave A (PR01–PR08) · Wave B (PR09–PR21) **MVP complete** · Wave C PR22–PR28 done · next PR29
