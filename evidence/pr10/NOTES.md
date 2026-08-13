# PR10 — Daily notes evidence notes

## Summary

**Daily notes live.** `DailyNoteService` auto-creates `daily/YYYY-MM-DD.md` with deterministic id `daily-YYYY-MM-DD` (UUID-derived for index). App Daily destination opens today with BlockEditor; iOS/default launch prefers Daily. DevHarness Daily panel loads `demo-daily` fixtures. Created-today inspector is **not** implemented (PR11).

## Identity scheme

| Piece | Value |
|---|---|
| Path | `daily/YYYY-MM-DD.md` |
| Logical id (frontmatter) | `daily-YYYY-MM-DD` |
| ObjectID (index/API) | Deterministic UUID `d01aYYYY-MMDD-4000-8000-6461696c7900` |
| Example | path `daily/2026-08-13.md`, id `daily-2026-08-13`, UUID `d01a2026-0813-4000-8000-6461696c7900` |

Two devices ensuring the same day write the same path + id (no fork).

## What landed

| Piece | Location |
|---|---|
| `DailyNoteIdentity`, `DailyNoteServing`, `ObjectID.daily` | `LociCore` |
| `DailyNoteService` | `LociVault` (Linux-tested) |
| Built-in Daily type seed | `VaultService.ensureSkeleton` / `SchemaStore` |
| App UI | `App/Features/DailyNotes/{DailyNoteFeature,DailyNoteView,DaySwitcher}` |
| Launch prefer Daily | `AppServices.selectedRoute = .daily`, `LociApp.task`, iOS Daily tab first |
| Demo CLI | `loci-daily-demo` + `scripts/demo-daily.sh` |
| Harness | Daily panel `?panel=daily` |

## Tests

- **95** package tests (was 84) — +ObjectID daily, FrontMatter daily key, DailyNoteService (create/idempotent/yesterday/path), schema daily seed
- Lint + build green

## Harness

- `http://127.0.0.1:5173/?panel=daily`
- Shows path, logical id, idempotent ensure, prev/today/next, markdown body
- Artifacts: `harness-daily.png`, `harness-daily-dom.html`, `daily.json`, `today.md`

## Artifacts

| File | Meaning |
|---|---|
| `test.log` | `./scripts/test.sh` (95 passed) |
| `lint.log` | `./scripts/lint.sh` |
| `demo-daily.log` | `./scripts/demo-daily.sh` |
| `daily.json` / `today.md` | Fixture extracts |
| `harness-daily.png` | Daily panel screenshot |
| `harness-daily-dom.html` | rendered DOM |

## Notes for PR11 (Created today)

- Add `CreatedTodayPanel` under DailyNotes (or inspector slot) bound to `IndexQuerying.created(on:)`
- **Do not** rewrite daily markdown when objects are created
- Daily inspector already reserves “Created today” title — wire live links only
- Prove: create Page → appears in panel; `daily/YYYY-MM-DD.md` bytes unchanged
