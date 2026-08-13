# Previous context — Loci agents

Handoff notes updated after each stacked PR. Read this before starting the next PR.

---

## Wave C (PR22–)

**Milestone:** Wave B MVP complete (PR09–PR21). Wave C depth: Collections → Queries → Graph → Calendar → Capture…

Next stack: **PR26 Capture surfaces**.

---

## PR25 — Calendar UI

**Branch:** `cursor/pr25-calendar-d2c1`  
**Based on:** `cursor/pr24-graph-d2c1` @ `68f7f7e`  
**Tip:** `e705413c6edf4b18ec3adfc0739b1939840c5582`*

### What landed

- **Core:** `CalendarScope` / `CalendarDayMarker` / `CalendarCell` / `CalendarGrid`; `CalendarGridBuilder` (month/week, Linux-testable); `Route.calendar`
- **Index:** `IndexQuerying.calendarMarkers`; `CalendarMarkersQuery` (daily presence + FTS content + creations in range)
- **Features/Calendar/:** `CalendarFeature`, `CalendarStore`, `CalendarView` (month/week + dots), `CalendarInspectorView` — day select → `DailyNoteServing.ensure` + `Navigating.open`
- **Demo:** `loci-calendar-demo` / `scripts/demo-calendar.sh` → `DevHarness/public/demo-calendar/`
- **Harness:** Studio **Calendar** panel at `?panel=calendar`
- **Tests:** CalendarGridBuilder (+6) + CalendarMarkersQuery (+2) → **219** total
- Evidence: `evidence/pr25/`
- Version: Index / Markdown → `*-pr25`; Vault → `0.25.0-pr25`

### How to run checks

```bash
export PATH=/opt/swift/usr/bin:$PATH
./scripts/lint.sh
./scripts/test.sh
./scripts/demo-calendar.sh
./scripts/run-harness.sh   # http://127.0.0.1:5173/?panel=calendar
```

### Pitfalls for PR26 (Capture surfaces)

- Share / widget / menu bar must append to **today’s daily** via deterministic `daily/YYYY-MM-DD.md` + `DailyNoteServing.ensureToday` — do not invent parallel inbox files
- Capture writes are real vault mutations (unlike calendar chrome); keep them coordinated and index-applied
- No feature→feature imports; Capture talks ObjectServing / DailyNoteServing / VaultServing protocols
- Extensions are Apple-only targets — keep Linux-testable core helpers in packages; DevHarness can stub the capture UX

### Next: PR26 — Capture surfaces

- Branch: `cursor/pr26-capture-d2c1`
- iOS Share extension (append to today or create typed object); home-screen widget (Open today / Quick add); macOS menu bar quick capture
- Depends on: PR10, PR08

---

## PR24 — Graph view

**Branch:** `cursor/pr24-graph-d2c1`

Graph from links table; type filter + caps. See `evidence/pr24/`.

### Still relevant

- Calendar dots are index-only (done in PR25) — do not confuse with capture writes
- Graph Studio destination remains; Calendar is a sibling Studio route

---

## PR23 — Saved queries + embeds

QueryEngine DSL; `.loci/queries/`; `/query` embeds. See `evidence/pr23/`.

---

## PR22 — Collections

Manual collections per type; membership vault JSON. See `evidence/pr22/`.

---

## Wave A (PR01–PR08) · Wave B (PR09–PR21) **MVP complete** · Wave C PR22–PR25 done · next PR26
