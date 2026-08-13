# Previous context — Loci agents

Handoff notes updated after each stacked PR. Read this before starting the next PR.

---

## PR12 — Custom object types + dashboards

**Branch:** `cursor/pr12-custom-types-d2c1`  
**Based on:** `cursor/pr11-created-today-d2c1` @ `8bf3480`

### What landed

- **`SchemaServing` CRUD:** `createType` / `renameType` / `deleteType` → `.loci/types/<slug>.json` + `objects/<slug>/`
- **`TypeSlug`:** name→slug, reserved `page`/`daily`, validation errors
- **Guards:** built-in Page/Daily refuse delete; non-empty custom types need `force`
- **UI:** `Features/ObjectTypes/{ObjectTypesFeature,UI/TypeList,TypeEditor,TypeDashboard}`
- **Sidebar:** Types section lists all schema types → opens dashboard
- **Demo:** `loci-types-demo` / `scripts/demo-types.sh` → `DevHarness/public/demo-types/`
- **Harness:** Types panel shows Books + Deep Work + delete guard
- **Tests:** **105** package tests (was 97)
- Evidence: `evidence/pr12/`
- Version: `LociVaultModule` → `0.12.0-pr12`

### How to run checks

```bash
export PATH=/opt/swift/usr/bin:$PATH
./scripts/lint.sh
./scripts/test.sh
./scripts/demo-types.sh
./scripts/run-harness.sh   # http://127.0.0.1:5173/?panel=types
```

### Pitfalls for PR13 (Properties)

- Types already have `properties: [PropertyDef]` — keep empty-array compatible
- Property values belong in YAML frontmatter via ObjectServing.save — not schema JSON
- Index needs property columns for filter/sort (extend IndexService carefully)
- Type dashboards currently list All from `objects(typeID:)` — property filters come next
- Do not rewrite type id/slug when renaming display name

### Next: PR13 — Properties system

- Branch: `cursor/pr13-properties-d2c1`

---

## PR11 — Created-today auto links

**Branch:** `cursor/pr11-created-today-d2c1`

`CreatedTodayPanel` from index; daily.md never rewritten on Page create. See `evidence/pr11/`.

### Still relevant

- Created-today already surfaces non-daily custom types automatically
- ObjectService must not touch daily notes on create

---

## Wave A (PR01–PR08) complete · Wave B: PR09–PR12 done · next PR13
