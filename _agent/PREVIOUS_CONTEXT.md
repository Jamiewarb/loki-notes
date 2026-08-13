# Previous context — Loci agents

Handoff notes updated after each stacked PR. Read this before starting the next PR.

---

## PR15 — PARA starter pack

**Branch:** `cursor/pr15-para-d2c1`  
**Based on:** `cursor/pr14-templates-d2c1` @ `39a96e8`

### What landed

- **`PARAPack.apply(to:)`** (idempotent): creates **Project** + **Area** types with starter properties + default templates (`project.default`, `area.default`)
- **Resource:** `#resource` tag approach (no Resource type) — documented in pack + Settings explainer
- **Archive:** `#archive` tag and/or `status=Archived`; `ArchiveFilter` + `SpaceSettings.hideArchived` / `TypeDashboardConfig.hideArchived` (no folder move)
- **UI:** Settings → “Apply PARA pack”; Onboarding hint; type dashboards hide archived
- **Demo:** `loci-para-demo` / `scripts/demo-para.sh` → `DevHarness/public/demo-para/`
- **Harness:** Settings PARA card + Types Project/Area section
- **Tests:** **127** package tests (was 120)
- Evidence: `evidence/pr15/`
- Version: `LociVaultModule` / `LociIndexModule` → `*-pr15`

### How to run checks

```bash
export PATH=/opt/swift/usr/bin:$PATH
./scripts/lint.sh
./scripts/test.sh
./scripts/demo-para.sh
./scripts/run-harness.sh   # http://127.0.0.1:5173/?panel=settings
```

### Pitfalls for PR16 (wiki-links)

- Project `area` property is still **text** — upgrade to object-select once LinkResolver exists
- `[[wiki-links]]` / `@` picker + backlinks panel are next
- Broken-link styling belongs with LinkResolver
- Do not put SQLite / index inside the vault
- Template ids remain `<type>.<slug>` (e.g. `project.default`)

### Next: PR16 — Wiki-links and backlinks

- Branch: `cursor/pr16-wikilinks-d2c1`
- Link picker, LinkResolver, write `[[…]]`, backlinks inspector, navigate + broken-link styling

---

## PR14 — Templates

**Branch:** `cursor/pr14-templates-d2c1`

Templates under `.loci/templates/`; star default; apply on create. See `evidence/pr14/`.

### Still relevant

- Template CRUD via `SchemaServing`
- Apply on create for objects + daily notes

---

## Wave A (PR01–PR08) complete · Wave B: PR09–PR15 done · next PR16
