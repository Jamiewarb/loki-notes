# Previous context — Loci agents

Handoff notes updated after each stacked PR. Read this before starting the next PR.

---

## PR13 — Properties system

**Branch:** `cursor/pr13-properties-d2c1`  
**Based on:** `cursor/pr12-custom-types-d2c1` @ `311da09`

### What landed

- **Property defs on types:** `SchemaServing.setProperties` / `upsertProperty` / `removeProperty` → `.loci/types/<slug>.json`
- **Kinds:** text, number, date, select, multiSelect, checkbox, url; object-select stub (comma-separated ids)
- **Object inspector:** `Features/Properties/PropertyEditorView` — values → YAML frontmatter via `ObjectServing.save`
- **Type defs UI:** `PropertyDefsEditorView` on type dashboard + types inspector
- **Index:** `properties_idx` written on save; `objects(typeID:propertyKey:equalsText:)` + `propertyIndex(objectID:)`
- **Demo:** `loci-properties-demo` / `scripts/demo-properties.sh` → `DevHarness/public/demo-properties/`
- **Harness:** Types panel shows Book defs + Deep Work property detail + inspector values
- **Tests:** **111** package tests (was 105)
- Evidence: `evidence/pr13/`
- Version: `LociVaultModule` / `LociIndexModule` → `*-pr13`

### How to run checks

```bash
export PATH=/opt/swift/usr/bin:$PATH
./scripts/lint.sh
./scripts/test.sh
./scripts/demo-properties.sh
./scripts/run-harness.sh   # http://127.0.0.1:5173/?panel=types
```

### Pitfalls for PR14 (Templates)

- Property values belong in frontmatter — template defaults should merge into `meta.properties` on create
- Empty `properties: []` on types remains valid
- Select values encode as tagged YAML `{kind: select, value: …}` for lossless round-trip
- Object-select is still a stub (no link picker until PR16)
- Do not put SQLite / index inside the vault

### Next: PR14 — Templates

- Branch: `cursor/pr14-templates-d2c1`
- Template CRUD per type (body markdown + default property values); star default; apply on create

---

## PR12 — Custom object types + dashboards

**Branch:** `cursor/pr12-custom-types-d2c1`

`SchemaServing` create/rename/delete; TypeList/TypeEditor/TypeDashboard; Books + Deep Work demo. See `evidence/pr12/`.

### Still relevant

- Type id/slug stays stable on rename
- Built-in Page/Daily refuse casual delete

---

## Wave A (PR01–PR08) complete · Wave B: PR09–PR13 done · next PR14
