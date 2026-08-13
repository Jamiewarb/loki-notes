# Previous context — Loci agents

Handoff notes updated after each stacked PR. Read this before starting the next PR.

---

## PR14 — Templates

**Branch:** `cursor/pr14-templates-d2c1`  
**Based on:** `cursor/pr13-properties-d2c1` @ `e451afe`

### What landed

- **Templates on disk:** `.loci/templates/<type>.<slug>.md` (YAML frontmatter + body) via `TemplateCodec`
- **Schema APIs:** `createTemplate` / `saveTemplate` / `listTemplates` / `deleteTemplate` / `setDefaultTemplate` / `defaultTemplate(for:)`
- **Star default:** `ObjectType.defaultTemplateID` + `templateIDs`
- **Apply on create:** `ObjectService` + `DailyNoteService` (when schema wired) prefills body + `meta.properties`; records `template:` in frontmatter
- **Re-apply empty:** `ObjectServing.applyTemplateIfEmpty`
- **UI:** `Features/Templates/` — editor on type dashboard, picker in inspector
- **Demo:** `loci-templates-demo` / `scripts/demo-templates.sh` → `DevHarness/public/demo-templates/`
- **Harness:** Types panel shows Book headings prefill + daily template body
- **Tests:** **120** package tests (was 111)
- Evidence: `evidence/pr14/`
- Version: `LociVaultModule` / `LociIndexModule` → `*-pr14`

### How to run checks

```bash
export PATH=/opt/swift/usr/bin:$PATH
./scripts/lint.sh
./scripts/test.sh
./scripts/demo-templates.sh
./scripts/run-harness.sh   # http://127.0.0.1:5173/?panel=types
```

### Pitfalls for PR15 (PARA)

- Starter pack should create Project/Area types with properties **and** default templates via existing SchemaServing APIs
- Archive is tag/status filter — not a filesystem folder move
- Resource may be a type or `#resource` guidance (PLAN)
- Do not put SQLite / index inside the vault
- Template ids are `<type>.<slug>` (e.g. `project.default`)

### Next: PR15 — PARA starter pack

- Branch: `cursor/pr15-para-d2c1`
- Onboarding or “Apply PARA pack”: Project, Area (+ Resource/Archive guidance); starter properties/templates; sidebar filters hiding archived

---

## PR13 — Properties system

**Branch:** `cursor/pr13-properties-d2c1`

Property defs on types; inspector values → YAML; `properties_idx`. See `evidence/pr13/`.

### Still relevant

- Select values encode as tagged YAML `{kind: select, value: …}`
- Object-select still a stub until PR16
- Empty `properties: []` on types remains valid

---

## Wave A (PR01–PR08) complete · Wave B: PR09–PR14 done · next PR15
