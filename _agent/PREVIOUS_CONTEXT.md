# Previous context — Loci agents

Handoff notes updated after each stacked PR. Read this before starting the next PR.

---

## PR11 — Created-today auto links

**Branch:** `cursor/pr11-created-today-d2c1`  
**Based on:** `cursor/pr10-daily-notes-d2c1` @ `a92d6cd`

### What landed

- **`CreatedTodayPanel`** under `Features/DailyNotes/UI/` — feeds from `IndexQuerying.created(on:)`
- **UX:** Excludes Daily-type rows (already on that note); Pages/future types show as links
- **Inspector:** `InspectorHostView` Daily route hosts the panel; `AppServices.inspectedDailyDay` tracks day switcher
- **CRITICAL invariant:** `ObjectService.create` does **not** rewrite daily `.md` — unit test asserts fingerprint + mtime + bytes
- **Demo:** `loci-created-today-demo` / `scripts/demo-created-today.sh` → `DevHarness/public/demo-created-today/`
- **Harness:** Daily panel + inspector list created-today; tap → detail placeholder (`Navigating.open` in app)
- **Tests:** **97** package tests (was 95)
- Evidence: `evidence/pr11/`

### How to run checks

```bash
export PATH=/opt/swift/usr/bin:$PATH
./scripts/lint.sh
./scripts/test.sh
./scripts/demo-created-today.sh
./scripts/run-harness.sh   # http://127.0.0.1:5173/?panel=daily
```

### Pitfalls for PR12 (Custom types)

- Created-today already surfaces non-daily types from the index — custom Books etc. appear without daily.md writes
- Add type CRUD + `types/<slug>/` + sidebar/dashboard; do not teach ObjectService to touch daily notes
- Schema remains merge-friendly per-type JSON

### Next: PR12 — Custom object types + dashboards

- Branch: `cursor/pr12-custom-types-d2c1`

---

## PR10 — Daily notes

**Branch:** `cursor/pr10-daily-notes-d2c1`

`DailyNoteService` + Daily destination + DaySwitcher. See `evidence/pr10/`.

### Still relevant

- Deterministic `daily/YYYY-MM-DD.md` + `daily-YYYY-MM-DD` id
- DailyNoteView uses BlockEditor / EditorSessionBridge — do not reintroduce TextEditor
- Created-today must stay inspector-only (done in PR11)

---

## Wave A (PR01–PR08) complete · Wave B: PR09–PR11 done · next PR12
