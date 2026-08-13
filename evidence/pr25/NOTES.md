# PR25 evidence — Calendar UI

| Check | Result |
|---|---|
| `./scripts/lint.sh` | passed (`evidence/pr25/lint.log`) |
| `./scripts/test.sh` | **219** tests, 0 failures (`evidence/pr25/test.log`) — was 211 on PR24 |
| `./scripts/demo-calendar.sh` | passed — August 2026, 42 cells, 3 marked, jump `daily/2026-08-14.md` (`demo.log`, `calendar.json`) |
| DevHarness `?panel=calendar` | served; DOM snapshot (`harness-calendar-dom.html`, `harness.html`, `harness.png`) |

## Demo proof

- Markers from `IndexQuerying.calendarMarkers` (daily presence, FTS content, creations)
- Day 13: daily + content + creations ≥ 2
- Day select jump creates `daily/2026-08-14.md` without rewriting day 13 (`chromeDidNotRewriteDaily13`)
- Month grid 42 cells / week 7 cells (Linux-testable `CalendarGridBuilder`)
- Index not inside vault (`indexInsideVault=false`)

## Handoff

Next: **PR26 Capture surfaces** — iOS Share extension, home-screen widget, macOS menu bar quick capture.
