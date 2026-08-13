# PR26 evidence — Capture surfaces

| Check | Result |
|---|---|
| `./scripts/lint.sh` | passed (`evidence/pr26/lint.log`) |
| `./scripts/test.sh` | **232** tests, 0 failures (`evidence/pr26/test.log`) — was 219 on PR25 |
| `./scripts/demo-capture.sh` | passed — inbox→daily drain + typed create (`demo.log`, `capture.json`) |
| DevHarness `?panel=capture` | served; DOM snapshot (`harness-capture-dom.html`, `harness.html`, `harness.png`) |

## Demo proof

- Extensions enqueue `.loci/inbox/*.json` (no index)
- Drain appends to `daily/YYYY-MM-DD.md` and creates typed `objects/page/…`
- Direct menu-bar append lands in today
- Pending inbox cleared after drain (`pendingAfter=0`)
- Index not inside vault (`indexInsideVault=false`)

## Handoff

Next: **PR27 Import** — generic markdown folder, Obsidian, Capacities export; dry-run summary.
