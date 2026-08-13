# Previous context — Loci agents

Handoff notes updated after each stacked PR. Read this before starting the next PR.

---

## PR10 — Daily notes

**Branch:** `cursor/pr10-daily-notes-d2c1`  
**Based on:** `cursor/pr09-block-editor-d2c1` @ `c23060f`

### What landed

- **`DailyNoteService`** in `LociVault` (Linux-testable): `ensure` / `ensureToday` / `open` + prev/next/select
- **Identity:** path `daily/YYYY-MM-DD.md`; frontmatter id `daily-YYYY-MM-DD`; deterministic UUID `d01aYYYY-MMDD-4000-8000-6461696c7900`
- **`DailyNoteIdentity` + `DailyNoteServing` + `ObjectID.daily` / `parsing:`** in `LociCore`; FrontMatter + Index accept date keys
- **Schema:** built-in Daily type seeded with Page on `ensureSkeleton` / bootstrap
- **App:** `Features/DailyNotes/{DailyNoteFeature,DailyNoteView,DaySwitcher}` — BlockEditor body; Daily destination live
- **Launch:** `AppServices` defaults `.daily`; `LociApp` bootstraps vault + ensure today; iOS Daily tab first
- **DevHarness:** Daily panel (`?panel=daily`) via `scripts/demo-daily.sh` / `loci-daily-demo`
- **Tests:** **95** package tests (was 84)
- Evidence: `evidence/pr10/`

### How to run checks

```bash
export PATH=/opt/swift/usr/bin:$PATH
./scripts/lint.sh
./scripts/test.sh
./scripts/demo-daily.sh
./scripts/run-harness.sh   # http://127.0.0.1:5173/?panel=daily
```

### Pitfalls for PR11 (Created today)

- Panel only: `IndexQuerying.created(on:)` → inspector links — **never** rewrite daily `.md` on object create
- Co-locate as `Features/DailyNotes/CreatedTodayPanel.swift` (or inspector module registered centrally)
- Daily note bytes must stay stable when creating Pages elsewhere
- Reuse existing `created(on:)` index query (PR07); wire publishers later if needed

### Next: PR11 — Created-today auto links

- Branch: `cursor/pr11-created-today-d2c1`

---

## PR09 — Block editor MVP

**Branch:** `cursor/pr09-block-editor-d2c1`

`EditorSession` + Apple BlockEditor; ObjectEditor uses BlockAST. See `evidence/pr09/`.

### Still relevant

- Debounced save via `EditorSessionBridge` → `ObjectServing.save`
- DailyNoteView reuses the same bridge — do not reintroduce TextEditor

---

## Wave A (PR01–PR08) — complete · Wave B: PR09–PR10 done · next PR11
